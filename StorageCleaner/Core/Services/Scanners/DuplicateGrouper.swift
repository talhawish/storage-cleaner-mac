import CryptoKit
import Foundation

/// Groups byte-identical files in three strictly narrowing stages:
/// 1. group by byte size (no reads),
/// 2. sub-group by a hash of the first 64 KiB (one small read per candidate),
/// 3. confirm with a full streamed SHA-256, hashed with bounded concurrency.
///
/// The prefix stage can only *split* size groups, never merge them, so the
/// results are identical to hashing every same-size file in full — with far
/// less I/O when large same-size files differ early (the common case for
/// videos and disk images).
enum DuplicateGrouper {
    static let prefixByteCount = 65_536

    static func groups(from files: [FileCandidate], minimumBytes: Int64) async -> [DuplicateGroup] {
        let candidatesBySize = Dictionary(grouping: files.filter { $0.bytes >= minimumBytes }, by: \.bytes)
        var groups: [DuplicateGroup] = []

        for (size, sameSizeCandidates) in candidatesBySize where sameSizeCandidates.count > 1 {
            guard !Task.isCancelled else { break }

            let byPrefix = Dictionary(grouping: sameSizeCandidates) { prefixHash(for: $0.url) }
            for prefixCandidates in byPrefix.values where prefixCandidates.count > 1 {
                if size <= Int64(prefixByteCount) {
                    // The prefix covered the whole file, so the prefix hash
                    // already *is* the full content hash — no second read.
                    let hash = prefixHash(for: prefixCandidates[0].url)
                    if let group = makeGroup(hash: hash, members: prefixCandidates) {
                        groups.append(group)
                    }
                } else {
                    groups.append(contentsOf: await confirmedGroups(for: prefixCandidates))
                }
            }
        }

        // Largest reclaim first; tie-break on hash so ordering is deterministic.
        return groups.sorted {
            $0.reclaimableBytes != $1.reclaimableBytes
                ? $0.reclaimableBytes > $1.reclaimableBytes
                : $0.contentHash < $1.contentHash
        }
    }

    // MARK: - Full-hash confirmation

    private static func confirmedGroups(for candidates: [FileCandidate]) async -> [DuplicateGroup] {
        let hashesByURL = await hashConcurrently(candidates.map(\.url))
        let byHash = Dictionary(grouping: candidates) { hashesByURL[$0.url] ?? $0.url.path }
        return byHash.compactMap { hash, members in
            makeGroup(hash: hash, members: members)
        }
    }

    private static func makeGroup(hash: String, members: [FileCandidate]) -> DuplicateGroup? {
        guard members.count > 1 else { return nil }
        let duplicateFiles = members
            .map { DuplicateFile(url: $0.url, bytes: $0.bytes, modifiedAt: modificationDate(for: $0.url)) }
            .sorted { $0.url.path < $1.url.path }
        let keep = DuplicateKeepStrategy.bestToKeep(from: duplicateFiles)
        return DuplicateGroup(contentHash: hash, files: duplicateFiles, keepURL: keep.url)
    }

    /// Full-file hashes computed in a bounded task group so a folder of large
    /// same-size files no longer hashes sequentially on a single thread.
    private static func hashConcurrently(_ urls: [URL]) async -> [URL: String] {
        let maxConcurrent = min(4, ProcessInfo.processInfo.activeProcessorCount)
        var hashes: [URL: String] = [:]
        var iterator = urls.makeIterator()

        await withTaskGroup(of: (URL, String).self) { group in
            func addNext() {
                guard !Task.isCancelled, let url = iterator.next() else { return }
                group.addTask { (url, contentHash(for: url)) }
            }
            for _ in 0..<maxConcurrent { addNext() }
            for await (url, hash) in group {
                hashes[url] = hash
                addNext()
            }
        }
        return hashes
    }

    // MARK: - Hashing primitives

    /// SHA-256 of the first 64 KiB. Falls back to the path when unreadable so
    /// unreadable files can never collide into one "duplicate" group.
    private static func prefixHash(for url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return url.path }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: prefixByteCount) else { return url.path }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Full streamed SHA-256 (1 MiB buffer) — never loads the file into memory.
    private static func contentHash(for url: URL) -> String {
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

    private static func modificationDate(for url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
