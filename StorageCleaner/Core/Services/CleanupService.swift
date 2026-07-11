import Foundation

enum CleanupError: Error, LocalizedError {
    case fileNotFound(URL)
    case deletionFailed(URL, Error)
    case nothingToDelete

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(url):
            "File not found: \(url.lastPathComponent)"
        case let .deletionFailed(url, error):
            "Failed to delete \(url.lastPathComponent): \(error.localizedDescription)"
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
}

struct FileManagerCleanupService: CleanupService {
    private static var trashPrefix: String { UserHomeDirectory.path + "/.Trash/" }

    func delete(urls: [URL]) async -> CleanupResult {
        let deletionURLs = Self.normalizedDeletionURLs(urls)
        guard !deletionURLs.isEmpty else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        return await withTaskGroup(of: CleanupResult.self) { group in
            for url in deletionURLs {
                group.addTask(priority: .userInitiated) {
                    Self.deleteSynchronously(url: url)
                }
            }

            var trashed: [URL] = []
            var deletedItems: [DeletedItem] = []
            var failed: [(URL, Error)] = []
            for await result in group {
                trashed.append(contentsOf: result.deletedURLs)
                deletedItems.append(contentsOf: result.deletedItems)
                failed.append(contentsOf: result.failedURLs)
            }
            return CleanupResult(
                deletedURLs: trashed,
                deletedItems: deletedItems,
                failedURLs: failed,
                totalBytesReclaimed: deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
            )
        }
    }

    private static func deleteSynchronously(url: URL) -> CleanupResult {
        let fileManager = FileManager.default
        var trashed: [URL] = []
        var deletedItems: [DeletedItem] = []
        var failed: [(URL, Error)] = []
        var totalBytes: Int64 = 0

        guard !Task.isCancelled else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [(url, CleanupError.fileNotFound(url))],
                totalBytesReclaimed: 0
            )
        }

        guard let size = sizeOfItem(at: url, fileManager: fileManager) else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }
        guard !Task.isCancelled else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        if url.path.hasPrefix(Self.trashPrefix) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                failed.append((url, error))
            }
        } else {
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
                trashed.append(resultingURL as? URL ?? url)
            } catch {
                failed.append((url, error))
            }
        }
        if failed.isEmpty {
            deletedItems.append(DeletedItem(originalURL: url, bytesReclaimed: size))
            totalBytes += size
        }
        return CleanupResult(
            deletedURLs: trashed,
            deletedItems: deletedItems,
            failedURLs: failed,
            totalBytesReclaimed: totalBytes
        )
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
        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let childURL as URL in enumerator {
            guard !Task.isCancelled else { return nil }
            let values = try? childURL.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }
}

private extension URL {
    func isDescendant(of possibleAncestor: URL) -> Bool {
        let childComponents = standardizedFileURL.pathComponents
        let ancestorComponents = possibleAncestor.standardizedFileURL.pathComponents
        guard childComponents.count > ancestorComponents.count else { return false }
        return zip(childComponents, ancestorComponents).allSatisfy { $0 == $1 }
    }
}
