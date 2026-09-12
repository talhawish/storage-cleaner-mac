import Foundation

enum CleanupError: Error, LocalizedError {
    case fileNotFound(URL)
    case deletionFailed(URL, Error)
    case containerAuthorizationRequired(URL, Error)
    case protectedSystemItem(URL)
    case nothingToDelete

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(url):
            "File not found: \(url.lastPathComponent)"
        case let .deletionFailed(url, error):
            "Failed to delete \(url.lastPathComponent): \(error.localizedDescription)"
        case let .containerAuthorizationRequired(url, _):
            "macOS did not authorize access to \(url.lastPathComponent)."
        case let .protectedSystemItem(url):
            "\(url.lastPathComponent) is protected by macOS and was left untouched."
        case .nothingToDelete:
            "No files selected for deletion"
        }
    }
}

/// One successfully removed item, tracked by its *original* location so callers can reconcile
/// findings and audit records. `CleanupResult.deletedURLs` instead holds the resulting Trash
/// locations, which are no longer the paths the app scanned.
struct DeletedItem: Sendable, Equatable {
    let originalURL: URL
    let bytesReclaimed: Int64
}

struct CleanupResult: Sendable {
    let deletedURLs: [URL]
    let deletedItems: [DeletedItem]
    let failedURLs: [(URL, Error)]
    let totalBytesReclaimed: Int64

    var succeeded: Bool { failedURLs.isEmpty }
    var deletedCount: Int { deletedItems.count }
    var failedCount: Int { failedURLs.count }
}

protocol CleanupService: Sendable {
    func delete(urls: [URL]) async -> CleanupResult
    func delete(urls: [URL], precomputedBytes: [URL: Int64]) async -> CleanupResult
}

extension CleanupService {
    /// Most test and feature-specific cleanup services only need the URL list. The live file
    /// manager service also accepts scan-time byte measurements so deleting a large directory
    /// does not walk the same tree a second time.
    func delete(urls: [URL], precomputedBytes: [URL: Int64]) async -> CleanupResult {
        await delete(urls: urls)
    }
}

struct FileManagerCleanupService: CleanupService {
    private static var trashPrefix: String { UserHomeDirectory.path + "/.Trash/" }
    private let trashMover: any TrashMoving

    init(trashMover: any TrashMoving = WorkspaceTrashMover()) {
        self.trashMover = trashMover
    }

    func delete(urls: [URL]) async -> CleanupResult {
        await delete(urls: urls, precomputedBytes: [:])
    }

    func delete(urls: [URL], precomputedBytes: [URL: Int64]) async -> CleanupResult {
        let deletionURLs = Self.normalizedDeletionURLs(urls)
        guard !deletionURLs.isEmpty else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        let normalizedBytes = Dictionary(
            precomputedBytes.map { ($0.key.standardizedFileURL, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let prepared = await Self.prepare(deletionURLs, precomputedBytes: normalizedBytes)
        let alreadyInTrash = prepared.items.filter(\.isAlreadyInTrash)
        let toRecycle = prepared.items.filter { !$0.isAlreadyInTrash }
        let permanentResult = await Self.removeFromTrash(alreadyInTrash)
        let recycleResult = await recycle(toRecycle)

        let deletedItems = permanentResult.deletedItems + recycleResult.deletedItems
        return CleanupResult(
            deletedURLs: permanentResult.deletedURLs + recycleResult.deletedURLs,
            deletedItems: deletedItems,
            failedURLs: prepared.failures + permanentResult.failedURLs + recycleResult.failedURLs,
            totalBytesReclaimed: deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
        )
    }

    private func recycle(_ items: [PreparedDeletion]) async -> CleanupResult {
        guard !items.isEmpty, !Task.isCancelled else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        var deletedURLs: [URL] = []
        var deletedItems: [DeletedItem] = []
        var failedURLs: [(URL, Error)] = []

        // NSWorkspace performs one coordinated Finder-style operation for the supplied URLs.
        // Passing thousands of paths in one request can leave its completion handler pending for
        // minutes (or indefinitely when one path is problematic). Smaller batches keep the
        // operation recoverable and let successful batches be reported independently.
        for start in stride(from: 0, to: items.count, by: Self.trashBatchSize) {
            guard !Task.isCancelled else { break }
            let end = min(start + Self.trashBatchSize, items.count)
            let result = await recycleBatch(Array(items[start..<end]))
            deletedURLs.append(contentsOf: result.deletedURLs)
            deletedItems.append(contentsOf: result.deletedItems)
            failedURLs.append(contentsOf: result.failedURLs)
        }

        return CleanupResult(
            deletedURLs: deletedURLs,
            deletedItems: deletedItems,
            failedURLs: failedURLs,
            totalBytesReclaimed: deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
        )
    }

    private func recycleBatch(_ items: [PreparedDeletion]) async -> CleanupResult {
        let moveResult = await trashMover.moveToTrash(items.map(\.url))
        let destinations = Dictionary(
            uniqueKeysWithValues: moveResult.destinationBySource.map {
                ($0.key.standardizedFileURL, $0.value)
            }
        )
        let fallbackError = moveResult.error ?? CocoaError(.fileWriteUnknown)
        let deletedItems = items.compactMap { item -> DeletedItem? in
            guard destinations[item.url] != nil else { return nil }
            return DeletedItem(originalURL: item.url, bytesReclaimed: item.bytes)
        }
        let failed = items.compactMap { item -> (URL, Error)? in
            guard destinations[item.url] == nil else { return nil }
            let error: Error = Self.isAppContainer(item.url)
                ? CleanupError.containerAuthorizationRequired(item.url, fallbackError)
                : fallbackError
            return (item.url, error)
        }

        return CleanupResult(
            deletedURLs: items.compactMap { destinations[$0.url] },
            deletedItems: deletedItems,
            failedURLs: failed,
            totalBytesReclaimed: deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
        )
    }

    private static let trashBatchSize = 100

    private static func prepare(
        _ urls: [URL],
        precomputedBytes: [URL: Int64]
    ) async -> (items: [PreparedDeletion], failures: [(URL, Error)]) {
        await withTaskGroup(of: PreparedDeletionResult.self) { group in
            for url in urls {
                group.addTask(priority: .userInitiated) {
                    prepareSynchronously(url, precomputedBytes: precomputedBytes)
                }
            }

            var items: [PreparedDeletion] = []
            var failures: [(URL, Error)] = []
            for await result in group {
                switch result {
                case let .ready(item): items.append(item)
                case let .failed(url, error): failures.append((url, error))
                case .cancelled: break
                }
            }
            return (items.sorted { $0.url.path < $1.url.path }, failures)
        }
    }

    private static func prepareSynchronously(
        _ url: URL,
        precomputedBytes: [URL: Int64]
    ) -> PreparedDeletionResult {
        let fileManager = FileManager.default
        guard !Task.isCancelled else { return .cancelled }

        guard !SystemJunkProtectionPolicy.protects(url) else {
            return .failed(url, CleanupError.protectedSystemItem(url))
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return .failed(url, CleanupError.fileNotFound(url))
        }

        let size = precomputedBytes[url.standardizedFileURL]
            ?? sizeOfItem(at: url, fileManager: fileManager)
        guard let size else {
            return .cancelled
        }
        guard !Task.isCancelled else { return .cancelled }

        return .ready(PreparedDeletion(
            url: url.standardizedFileURL,
            bytes: size,
            isAlreadyInTrash: url.path.hasPrefix(Self.trashPrefix)
        ))
    }

    private static func removeFromTrash(_ items: [PreparedDeletion]) async -> CleanupResult {
        await withTaskGroup(of: CleanupResult.self) { group in
            for item in items {
                group.addTask(priority: .userInitiated) {
                    do {
                        try FileManager.default.removeItem(at: item.url)
                        let deleted = DeletedItem(originalURL: item.url, bytesReclaimed: item.bytes)
                        return CleanupResult(
                            deletedURLs: [item.url],
                            deletedItems: [deleted],
                            failedURLs: [],
                            totalBytesReclaimed: item.bytes
                        )
                    } catch {
                        return CleanupResult(
                            deletedURLs: [],
                            deletedItems: [],
                            failedURLs: [(item.url, error)],
                            totalBytesReclaimed: 0
                        )
                    }
                }
            }

            var deletedURLs: [URL] = []
            var deletedItems: [DeletedItem] = []
            var failedURLs: [(URL, Error)] = []
            for await result in group {
                deletedURLs.append(contentsOf: result.deletedURLs)
                deletedItems.append(contentsOf: result.deletedItems)
                failedURLs.append(contentsOf: result.failedURLs)
            }
            return CleanupResult(
                deletedURLs: deletedURLs,
                deletedItems: deletedItems,
                failedURLs: failedURLs,
                totalBytesReclaimed: deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
            )
        }
    }

    private static func isAppContainer(_ url: URL) -> Bool {
        [SystemJunkPaths.containers, SystemJunkPaths.groupContainers].contains { root in
            url.standardizedFileURL == root.standardizedFileURL
                || url.standardizedFileURL.isDescendant(of: root.standardizedFileURL)
        }
    }

    /// Deleting both a directory and one of its descendants concurrently races the filesystem:
    /// whichever task wins makes the other path disappear and turns a successful cleanup into a
    /// false failure. Keep the highest selected ancestor only, while preserving distinct siblings.
    private static func normalizedDeletionURLs(_ urls: [URL]) -> [URL] {
        let unique = Array(Set(urls.map { $0.standardizedFileURL }))
            .sorted {
                if $0.pathComponents.count != $1.pathComponents.count {
                    return $0.pathComponents.count < $1.pathComponents.count
                }
                return $0.path.localizedStandardCompare($1.path) == .orderedAscending
            }

        var result: [URL] = []
        for url in unique where !result.contains(where: { url.isDescendant(of: $0) }) {
            result.append(url)
        }
        return result
    }

    private static func sizeOfItem(at url: URL, fileManager: FileManager) -> Int64? {
        guard !Task.isCancelled else { return nil }

        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))

        if values?.isDirectory == true {
            return directorySize(at: url, fileManager: fileManager)
        }

        return Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }

    private static func directorySize(at url: URL, fileManager: FileManager) -> Int64? {
        let total = FileSystemItemSizer.allocatedSize(of: url, fileManager: fileManager)
        return Task.isCancelled ? nil : total
    }
}

private struct PreparedDeletion: Sendable {
    let url: URL
    let bytes: Int64
    let isAlreadyInTrash: Bool
}

private enum PreparedDeletionResult: Sendable {
    case ready(PreparedDeletion)
    case failed(URL, any Error)
    case cancelled
}

private extension URL {
    func isDescendant(of possibleAncestor: URL) -> Bool {
        let childComponents = standardizedFileURL.pathComponents
        let ancestorComponents = possibleAncestor.standardizedFileURL.pathComponents
        guard childComponents.count > ancestorComponents.count else { return false }
        return zip(childComponents, ancestorComponents).allSatisfy { $0 == $1 }
    }
}
