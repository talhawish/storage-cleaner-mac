import Foundation

struct FileSystemCollector: Sendable {
    private static let sizeKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

    func collectExistingItems(at urls: [URL]) -> [FileCandidate] {
        let fileManager = FileManager.default

        return urls.compactMap { url in
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }

            return FileCandidate(
                url: url,
                bytes: sizeOfItem(at: url)
            )
        }
    }

    func collectFiles(
        at roots: [URL],
        matching matcher: @Sendable (URL) -> Bool,
        limit: Int = 2_000
    ) -> [FileCandidate] {
        let fileManager = FileManager.default
        var candidates: [FileCandidate] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else { return candidates }
            collectFiles(at: root, matching: matcher, limit: limit, into: &candidates)
        }

        return candidates
    }

    func collectLikelyDuplicates(
        at roots: [URL],
        extensions allowedExtensions: Set<String>,
        minimumBytes: Int64,
        limit: Int = 2_000
    ) -> [FileCandidate] {
        let files = collectFiles(
            at: roots,
            matching: { url in
                allowedExtensions.contains(url.pathExtension.lowercased())
            },
            limit: limit
        )

        return duplicateCandidates(from: files, minimumBytes: minimumBytes)
    }

    private func collectFiles(
        at root: URL,
        matching matcher: @Sendable (URL) -> Bool,
        limit: Int,
        into candidates: inout [FileCandidate]
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
            guard matcher(url) else { continue }

            let values = try? url.resourceValues(forKeys: Self.sizeKeys)
            guard values?.isRegularFile == true else { continue }

            candidates.append(FileCandidate(url: url, bytes: allocatedSize(from: values)))
        }
    }

    private func duplicateCandidates(from files: [FileCandidate], minimumBytes: Int64) -> [FileCandidate] {
        let grouped = Dictionary(grouping: files) { candidate in
            duplicateKey(for: candidate)
        }

        return grouped.values.flatMap { group in
            group.count > 1 ? group.dropFirst() : []
        }
        .filter { $0.bytes >= minimumBytes }
    }

    private func duplicateKey(for candidate: FileCandidate) -> String {
        let name = candidate.url.deletingPathExtension().lastPathComponent
            .lowercased()
            .replacingOccurrences(of: #" copy( \d+)?$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\(\d+\)$"#, with: "", options: .regularExpression)

        return "\(name)-\(candidate.bytes)"
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
