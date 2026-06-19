import CryptoKit
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
        matching matcher: @Sendable (URL) -> Bool,
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

    /// Collects byte-identical duplicate groups under `roots`. Each returned group has 2+ copies
    /// and a recommended file to keep; the rest are safe to remove.
    func collectDuplicateGroups(
        at roots: [URL],
        extensions allowedExtensions: Set<String>,
        minimumBytes: Int64,
        limit: Int = 2_000
    ) -> DuplicateCollectionResult {
        let result = collectFiles(
            at: roots,
            matching: { url in
                allowedExtensions.contains(url.pathExtension.lowercased())
            },
            limit: limit
        )

        return DuplicateCollectionResult(
            groups: duplicateGroups(from: result.candidates, minimumBytes: minimumBytes),
            inspectedItemCount: result.inspectedItemCount
        )
    }

    private func collectFiles(
        at root: URL,
        matching matcher: @Sendable (URL) -> Bool,
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

        for case let url as URL in enumerator {
            guard !Task.isCancelled else { return }
            guard policy.prioritizeLargest || candidates.count < policy.limit else { return }
            let values = try? url.resourceValues(forKeys: Self.sizeKeys)
            guard values?.isRegularFile == true else { continue }
            inspectedItemCount += 1

            guard matcher(url) else { continue }

            let candidate = FileCandidate(url: url, bytes: allocatedSize(from: values))
            if policy.prioritizeLargest {
                retainLargest(candidate, in: &candidates, limit: policy.limit)
            } else {
                candidates.append(candidate)
            }
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

        for case let url as URL in enumerator {
            guard !Task.isCancelled else { return }
            guard candidates.count < policy.limit else { return }

            let depth = url.pathComponents.count - rootDepth
            if depth > policy.maxDepth {
                enumerator.skipDescendants()
                continue
            }

            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            inspectedItemCount += 1

            guard matcher(url) else { continue }
            candidates.append(FileCandidate(url: url, bytes: sizeOfItem(at: url)))
            enumerator.skipDescendants()
        }
    }

    /// Inserts `candidate` while keeping at most `limit` of the largest candidates by byte size.
    private func retainLargest(_ candidate: FileCandidate, in candidates: inout [FileCandidate], limit: Int) {
        guard candidates.count >= limit else {
            candidates.append(candidate)
            return
        }

        guard let smallestIndex = candidates.indices.min(by: { candidates[$0].bytes < candidates[$1].bytes }),
              candidates[smallestIndex].bytes < candidate.bytes else {
            return
        }

        candidates[smallestIndex] = candidate
    }

    private func duplicateGroups(from files: [FileCandidate], minimumBytes: Int64) -> [DuplicateGroup] {
        let candidatesBySize = Dictionary(grouping: files.filter { $0.bytes >= minimumBytes }, by: \.bytes)
        var groups: [DuplicateGroup] = []

        for sameSizeCandidates in candidatesBySize.values where sameSizeCandidates.count > 1 {
            let groupedByHash = Dictionary(grouping: sameSizeCandidates) { candidate in
                contentHash(for: candidate.url)
            }

            for (hash, members) in groupedByHash where members.count > 1 {
                let duplicateFiles = members
                    .map { DuplicateFile(url: $0.url, bytes: $0.bytes, modifiedAt: modificationDate(for: $0.url)) }
                    .sorted { $0.url.path < $1.url.path }
                let keep = DuplicateKeepStrategy.bestToKeep(from: duplicateFiles)
                groups.append(DuplicateGroup(contentHash: hash, files: duplicateFiles, keepURL: keep.url))
            }
        }

        // Largest reclaim first; tie-break on hash so ordering is deterministic.
        return groups.sorted {
            $0.reclaimableBytes != $1.reclaimableBytes
                ? $0.reclaimableBytes > $1.reclaimableBytes
                : $0.contentHash < $1.contentHash
        }
    }

    private func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func contentHash(for url: URL) -> String {
        guard let stream = InputStream(url: url) else { return url.path }

        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            guard readCount > 0 else { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: readCount))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func sizeOfItem(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: Self.sizeKeys)
        if values?.isRegularFile == true {
            return allocatedSize(from: values)
        }

        return directorySize(at: url)
    }

    private func directorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var total: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(Self.sizeKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return total
        }

        for case let childURL as URL in enumerator {
            guard !Task.isCancelled else { return total }

            let values = try? childURL.resourceValues(forKeys: Self.sizeKeys)
            guard values?.isRegularFile == true else { continue }
            total += allocatedSize(from: values)
        }

        return total
    }

    private func allocatedSize(from values: URLResourceValues?) -> Int64 {
        Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }
}
