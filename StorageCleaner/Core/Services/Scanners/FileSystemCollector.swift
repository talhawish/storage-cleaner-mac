import Foundation

struct FileSystemCollector: Sendable {
    private static let sizeKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

    func collectExistingItems(at urls: [URL]) -> FileCollectionResult {
        let fileManager = FileManager.default
        var inspectedItemCount = 0

        let candidates: [FileCandidate] = urls.compactMap { url -> FileCandidate? in
            inspectedItemCount += 1
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }

            return FileCandidate(
                url: url,
                bytes: sizeOfItem(at: url)
            )
        }

        return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
    }

    /// Collects regular files under `roots` that satisfy `matcher`, capping results at `limit`.
    ///
    /// When `prioritizeLargest` is `false` (the default) traversal stops at the first `limit`
    /// matches. When `true`, traversal continues and retains the `limit` *largest* candidates by
    /// byte size — so lowering a size floor can never silently drop the biggest files in favor of
    /// whichever happened to be enumerated first.
    func collectFiles(
        at roots: [URL],
        matching matcher: @Sendable (FileRecord) -> Bool,
        limit: Int = 2_000,
        prioritizeLargest: Bool = false
    ) -> FileCollectionResult {
        let fileManager = FileManager.default
        let policy = CollectionPolicy(limit: limit, prioritizeLargest: prioritizeLargest)
        var candidates: [FileCandidate] = []
        var inspectedItemCount = 0

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else {
                return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
            }
            collectFiles(
                at: root,
                matching: matcher,
                policy: policy,
                into: &candidates,
                inspectedItemCount: &inspectedItemCount
            )
        }

        return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
    }

    /// Collects directories under `roots` that satisfy `matcher`, capping results at `limit`.
    /// Matching directories are measured as a single candidate and their descendants are skipped so
    /// nested dependency folders are not double-counted.
    func collectDirectories(
        at roots: [URL],
        matching matcher: @Sendable (URL) -> Bool,
        maxDepth: Int,
        limit: Int = 500
    ) -> FileCollectionResult {
        let fileManager = FileManager.default
        var candidates: [FileCandidate] = []
        var inspectedItemCount = 0

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else {
                return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
            }
            collectDirectories(
                at: root,
                matching: matcher,
                policy: DirectoryCollectionPolicy(maxDepth: maxDepth, limit: limit),
                into: &candidates,
                inspectedItemCount: &inspectedItemCount
            )
        }

        return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
    }

    /// How `collectFiles` caps and prioritizes its results.
    private struct CollectionPolicy {
        let limit: Int
        let prioritizeLargest: Bool
    }

    private struct DirectoryCollectionPolicy {
        let maxDepth: Int
        let limit: Int
    }

    private func collectFiles(
        at root: URL,
        matching matcher: @Sendable (FileRecord) -> Bool,
        policy: CollectionPolicy,
        into candidates: inout [FileCandidate],
        inspectedItemCount: inout Int
    ) {
        let fileManager = FileManager.default
        guard policy.prioritizeLargest || candidates.count < policy.limit else { return }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(Self.sizeKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        while true {
            guard !Task.isCancelled else { return }
            guard policy.prioritizeLargest || candidates.count < policy.limit else { return }
            let hasItem = autoreleasepool {
                guard let url = enumerator.nextObject() as? URL else { return false }
                let values = try? url.resourceValues(forKeys: Self.sizeKeys)
                guard values?.isRegularFile == true else { return true }
                inspectedItemCount += 1

                let record = FileRecord(url: url, bytes: allocatedSize(from: values))
                guard matcher(record) else { return true }

                let candidate = FileCandidate(url: record.url, bytes: record.bytes)
                if policy.prioritizeLargest {
                    candidates.retainLargest(candidate, limit: policy.limit)
                } else {
                    candidates.append(candidate)
                }
                return true
            }
            guard hasItem else { return }
        }
    }

    private func collectDirectories(
        at root: URL,
        matching matcher: @Sendable (URL) -> Bool,
        policy: DirectoryCollectionPolicy,
        into candidates: inout [FileCandidate],
        inspectedItemCount: inout Int
    ) {
        let fileManager = FileManager.default
        guard candidates.count < policy.limit else { return }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        let rootDepth = root.pathComponents.count

        while true {
            guard !Task.isCancelled else { return }
            guard candidates.count < policy.limit else { return }
            let hasItem = autoreleasepool {
                guard let url = enumerator.nextObject() as? URL else { return false }
                let depth = url.pathComponents.count - rootDepth
                if depth > policy.maxDepth {
                    enumerator.skipDescendants()
                    return true
                }

                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else { return true }
                inspectedItemCount += 1

                guard matcher(url) else { return true }
                candidates.append(FileCandidate(url: url, bytes: sizeOfItem(at: url)))
                enumerator.skipDescendants()
                return true
            }
            guard hasItem else { return }
        }
    }

    private func sizeOfItem(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: Self.sizeKeys)
        if values?.isRegularFile == true {
            return allocatedSize(from: values)
        }

        return directorySize(at: url)
    }

    private func directorySize(at url: URL) -> Int64 {
        FileSystemItemSizer.allocatedSize(of: url, options: [.skipsHiddenFiles])
    }

    private func allocatedSize(from values: URLResourceValues?) -> Int64 {
        Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }
}
