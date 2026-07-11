import Foundation

/// Shared caps for file traversal so direct walks and snapshot-backed walks
/// enforce identical limits.
enum FileTraversalDefaults {
    /// Maximum matched candidates a single scanner keeps.
    static let fileLimit = 2_000
}

/// Abstraction over "give me the regular files under these roots that match".
/// `FileSystemCollector` implements it with a direct walk; `SnapshotTraversal`
/// implements it against a per-scan `DirectorySnapshotCache` so ten scanners
/// interested in `~/Downloads` share one traversal instead of walking it ten
/// times concurrently.
protocol FileTraversing: Sendable {
    func collectMatchingFiles(
        at roots: [URL],
        matching matcher: @escaping @Sendable (FileRecord) -> Bool,
        limit: Int,
        prioritizeLargest: Bool
    ) async -> FileCollectionResult
}

extension FileSystemCollector: FileTraversing {
    func collectMatchingFiles(
        at roots: [URL],
        matching matcher: @escaping @Sendable (FileRecord) -> Bool,
        limit: Int,
        prioritizeLargest: Bool
    ) async -> FileCollectionResult {
        collectFiles(at: roots, matching: matcher, limit: limit, prioritizeLargest: prioritizeLargest)
    }
}

/// One complete, read-only enumeration of a root directory: every regular
/// file (with prefetched sizes), capped so memory stays bounded on
/// pathological folders.
struct DirectorySnapshot: Sendable {
    let root: URL
    let records: [FileRecord]
    let inspectedItemCount: Int
    /// `true` when the walk hit `DirectorySnapshotCache.maxRecordsPerRoot`
    /// and stopped early; consumers still get the first N records.
    let truncated: Bool
}

/// Per-scan memoization of directory walks. The first scanner to request a
/// root triggers one detached traversal; every other scanner interested in the
/// same root awaits the same task. `beginScan()` starts a fresh generation so
/// a rescan always re-reads the disk, and `endScan()` cancels in-flight walks
/// when the scan stream terminates.
///
/// This is the `LazyInstalledAppCatalog` idea upgraded with actor isolation
/// and per-scan invalidation (the catalog memoizes for the whole process,
/// which would serve stale listings to rescans).
actor DirectorySnapshotCache {
    /// A `FileRecord` is a few hundred bytes, so the worst case per root is
    /// tens of MB — bounded even on enormous Downloads folders.
    static let maxRecordsPerRoot = 100_000

    private var snapshotTasks: [URL: Task<DirectorySnapshot, Never>] = [:]
    private var projectRootTasks: [URL: Task<[URL], Never>] = [:]

    /// Starts a fresh generation: cancels and forgets every memoized walk so
    /// the next request re-reads the disk. Call once per scan, before any
    /// scanner runs.
    func beginScan() {
        cancelAll()
    }

    /// Cancels in-flight walks. Call when the scan stream terminates so
    /// detached traversals never outlive a cancelled scan.
    func endScan() {
        cancelAll()
    }

    func snapshot(of root: URL) async -> DirectorySnapshot {
        let key = root.standardizedFileURL
        if let task = snapshotTasks[key] {
            return await task.value
        }
        let task = Task.detached(priority: .utility) {
            Self.walk(root: key)
        }
        snapshotTasks[key] = task
        return await task.value
    }

    /// Detected project roots under `root`, memoized per scan. Shared by the
    /// duplicate scanners so project detection walks each root once instead of
    /// once per scanner.
    func projectRoots(under root: URL) async -> [URL] {
        let key = root.standardizedFileURL
        if let task = projectRootTasks[key] {
            return await task.value
        }
        let task = Task.detached(priority: .utility) {
            DuplicateProjectRootDetector().detect(in: [key])
        }
        projectRootTasks[key] = task
        return await task.value
    }

    private func cancelAll() {
        for task in snapshotTasks.values {
            task.cancel()
        }
        for task in projectRootTasks.values {
            task.cancel()
        }
        snapshotTasks.removeAll()
        projectRootTasks.removeAll()
    }

    /// Synchronous full walk of one root. Runs on a detached utility task so
    /// the blocking `FileManager` enumeration never occupies a cooperative
    /// thread that scanners need.
    private static func walk(root: URL) -> DirectorySnapshot {
        let sizeKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .fileSizeKey]
        let fileManager = FileManager.default
        var records: [FileRecord] = []
        var inspectedItemCount = 0
        var truncated = false

        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(sizeKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
              ) else {
            return DirectorySnapshot(root: root, records: [], inspectedItemCount: 0, truncated: false)
        }

        for case let url as URL in enumerator {
            guard !Task.isCancelled else { break }
            guard records.count < maxRecordsPerRoot else {
                truncated = true
                break
            }
            let values = try? url.resourceValues(forKeys: sizeKeys)
            guard values?.isRegularFile == true else { continue }
            inspectedItemCount += 1
            records.append(FileRecord(
                url: url,
                bytes: Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            ))
        }

        return DirectorySnapshot(
            root: root,
            records: records,
            inspectedItemCount: inspectedItemCount,
            truncated: truncated
        )
    }
}

/// `FileTraversing` backed by a shared `DirectorySnapshotCache`: filters the
/// memoized per-root snapshots instead of re-walking the tree, while enforcing
/// the same `limit` / `prioritizeLargest` semantics as the direct collector.
struct SnapshotTraversal: FileTraversing {
    let cache: DirectorySnapshotCache

    func collectMatchingFiles(
        at roots: [URL],
        matching matcher: @escaping @Sendable (FileRecord) -> Bool,
        limit: Int,
        prioritizeLargest: Bool
    ) async -> FileCollectionResult {
        var candidates: [FileCandidate] = []
        var inspectedItemCount = 0

        for root in roots {
            guard !Task.isCancelled else { break }
            let snapshot = await cache.snapshot(of: root)
            inspectedItemCount += snapshot.inspectedItemCount

            for record in snapshot.records {
                guard prioritizeLargest || candidates.count < limit else { break }
                guard matcher(record) else { continue }

                let candidate = FileCandidate(url: record.url, bytes: record.bytes)
                if prioritizeLargest {
                    candidates.retainLargest(candidate, limit: limit)
                } else {
                    candidates.append(candidate)
                }
            }
        }

        return FileCollectionResult(candidates: candidates, inspectedItemCount: inspectedItemCount)
    }
}
