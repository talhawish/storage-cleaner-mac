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

struct CleanupResult: Sendable {
    let deletedURLs: [URL]
    let failedURLs: [(URL, Error)]
    let totalBytesReclaimed: Int64

    var succeeded: Bool { failedURLs.isEmpty }
    var deletedCount: Int { deletedURLs.count }
    var failedCount: Int { failedURLs.count }
}

protocol CleanupService: Sendable {
    func delete(urls: [URL]) async -> CleanupResult
}

struct FileManagerCleanupService: CleanupService {
    func delete(urls: [URL]) async -> CleanupResult {
        let fileManager = FileManager.default
        var deleted: [URL] = []
        var failed: [(URL, Error)] = []
        var totalBytes: Int64 = 0

        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else {
                continue
            }

            let size = sizeOfItem(at: url, fileManager: fileManager)

            do {
                try fileManager.removeItem(at: url)
                deleted.append(url)
                totalBytes += size
            } catch {
                failed.append((url, error))
            }
        }

        return CleanupResult(
            deletedURLs: deleted,
            failedURLs: failed,
            totalBytesReclaimed: totalBytes
        )
    }

    private func sizeOfItem(at url: URL, fileManager: FileManager) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))

        if values?.isDirectory == true {
            return directorySize(at: url, fileManager: fileManager)
        }

        return Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }

    private func directorySize(at url: URL, fileManager: FileManager) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let childURL as URL in enumerator {
            let values = try? childURL.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }
}
