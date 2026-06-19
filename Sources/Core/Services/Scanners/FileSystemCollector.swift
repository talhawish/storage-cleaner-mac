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

    func collectFiles(
        at roots: [URL],
        matching matcher: @Sendable (URL) -> Bool,
        limit: Int = 2_000
    ) -> FileCollectionResult {
        let fileManager = FileManager.default
        var candidates: [FileCandidate] = []
        var inspectedItemCount = 0

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else {
                return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
            }
            collectFiles(
                at: root,
                matching: matcher,
                limit: limit,
                into: &candidates,
                inspectedItemCount: &inspectedItemCount
            )
        }

        return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
    }

    func collectLikelyDuplicates(
        at roots: [URL],
        extensions allowedExtensions: Set<String>,
        minimumBytes: Int64,
        limit: Int = 2_000
    ) -> FileCollectionResult {
        let result = collectFiles(
            at: roots,
            matching: { url in
                allowedExtensions.contains(url.pathExtension.lowercased())
            },
            limit: limit
        )

        return FileCollectionResult(
            candidates: duplicateCandidates(from: result.candidates, minimumBytes: minimumBytes),
            inspectedItemCount: result.inspectedItemCount
        )
    }

    private func collectFiles(
        at root: URL,
        matching matcher: @Sendable (URL) -> Bool,
        limit: Int,
        into candidates: inout [FileCandidate],
        inspectedItemCount: inout Int
    ) {
        let fileManager = FileManager.default
        guard candidates.count < limit else { return }

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(Self.sizeKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        for case let url as URL in enumerator {
            guard candidates.count < limit, !Task.isCancelled else { return }
            let values = try? url.resourceValues(forKeys: Self.sizeKeys)
            guard values?.isRegularFile == true else { continue }
            inspectedItemCount += 1

            guard matcher(url) else { continue }

            candidates.append(FileCandidate(url: url, bytes: allocatedSize(from: values)))
        }
    }

    private func duplicateCandidates(from files: [FileCandidate], minimumBytes: Int64) -> [FileCandidate] {
        let candidatesBySize = Dictionary(grouping: files.filter { $0.bytes >= minimumBytes }, by: \.bytes)
        var duplicates: [FileCandidate] = []

        for sameSizeCandidates in candidatesBySize.values where sameSizeCandidates.count > 1 {
            let groupedByHash = Dictionary(grouping: sameSizeCandidates) { candidate in
                contentHash(for: candidate.url)
            }

            let matchedDuplicates = groupedByHash.values.flatMap { group in
                group.count > 1 ? group.dropFirst() : []
            }
            duplicates.append(contentsOf: matchedDuplicates)
        }

        return duplicates.sorted { $0.bytes > $1.bytes }
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
