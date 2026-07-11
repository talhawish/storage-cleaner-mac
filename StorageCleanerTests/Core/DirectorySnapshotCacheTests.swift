import Foundation
import XCTest
@testable import StorageCleaner

final class DirectorySnapshotCacheTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ name: String, bytes: Int = 1_024) throws {
        try Data(count: bytes).write(to: root.appending(path: name))
    }

    func testSnapshotListsRegularFilesWithSizes() async throws {
        try write("a.mov", bytes: 4_096)
        try write("b.txt", bytes: 1_024)

        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        let snapshot = await cache.snapshot(of: root)

        XCTAssertEqual(snapshot.records.count, 2)
        XCTAssertEqual(snapshot.inspectedItemCount, 2)
        XCTAssertFalse(snapshot.truncated)
        let mov = try XCTUnwrap(snapshot.records.first { $0.pathExtensionLowercased == "mov" })
        XCTAssertGreaterThanOrEqual(mov.bytes, 4_096)
        XCTAssertEqual(mov.nameLowercased, "a.mov")
    }

    /// The whole point of the cache: a second request within the same scan
    /// must serve the memoized walk, not re-read the disk.
    func testSnapshotIsMemoizedWithinAScanGeneration() async throws {
        try write("first.bin")

        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        let before = await cache.snapshot(of: root)
        XCTAssertEqual(before.records.count, 1)

        try write("added-later.bin")
        let after = await cache.snapshot(of: root)

        XCTAssertEqual(after.records.count, 1, "memoized snapshot must not re-walk the directory")
    }

    /// `beginScan()` starts a fresh generation so rescans see disk changes.
    func testBeginScanInvalidatesPreviousGeneration() async throws {
        try write("first.bin")

        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        _ = await cache.snapshot(of: root)

        try write("added-later.bin")
        await cache.beginScan()
        let fresh = await cache.snapshot(of: root)

        XCTAssertEqual(fresh.records.count, 2)
    }

    func testConcurrentRequestersReceiveIdenticalSnapshots() async throws {
        try write("a.bin")
        try write("b.bin")

        let cache = DirectorySnapshotCache()
        await cache.beginScan()

        let target: URL = root
        async let first = cache.snapshot(of: target)
        async let second = cache.snapshot(of: target)
        async let third = cache.snapshot(of: target)
        let snapshots = await [first, second, third]

        for snapshot in snapshots {
            XCTAssertEqual(snapshot.records.map(\.url).sorted { $0.path < $1.path },
                           snapshots[0].records.map(\.url).sorted { $0.path < $1.path })
        }
    }

    func testMissingRootYieldsEmptySnapshot() async {
        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        let snapshot = await cache.snapshot(of: root.appending(path: "does-not-exist"))

        XCTAssertTrue(snapshot.records.isEmpty)
        XCTAssertEqual(snapshot.inspectedItemCount, 0)
    }

    /// Snapshot-backed traversal must be behaviorally identical to the direct
    /// collector — same matches, same limit semantics, same largest-retention.
    func testSnapshotTraversalMatchesDirectCollector() async throws {
        let nested = root.appending(path: "nested", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try write("big.mov", bytes: 100_000)
        try write("small.mov", bytes: 1_000)
        try write("skip.txt", bytes: 50_000)
        try Data(count: 25_000).write(to: nested.appending(path: "mid.mov"))

        let matcher: @Sendable (FileRecord) -> Bool = { $0.pathExtensionLowercased == "mov" }
        let direct = await FileSystemCollector().collectMatchingFiles(
            at: [root], matching: matcher, limit: 2_000, prioritizeLargest: false
        )
        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        let shared = await SnapshotTraversal(cache: cache).collectMatchingFiles(
            at: [root], matching: matcher, limit: 2_000, prioritizeLargest: false
        )

        XCTAssertEqual(
            Set(direct.candidates.map(\.url.lastPathComponent)),
            Set(shared.candidates.map(\.url.lastPathComponent))
        )
        XCTAssertEqual(Set(shared.candidates.map(\.url.lastPathComponent)), ["big.mov", "small.mov", "mid.mov"])
    }

    func testSnapshotTraversalHonorsLimitAndPrioritizeLargest() async throws {
        try write("tiny.bin", bytes: 1_000)
        try write("small.bin", bytes: 10_000)
        try write("large.bin", bytes: 100_000)
        try write("huge.bin", bytes: 1_000_000)

        let cache = DirectorySnapshotCache()
        await cache.beginScan()
        let traversal = SnapshotTraversal(cache: cache)

        let capped = await traversal.collectMatchingFiles(
            at: [root], matching: { _ in true }, limit: 2, prioritizeLargest: false
        )
        XCTAssertEqual(capped.candidates.count, 2)

        let largest = await traversal.collectMatchingFiles(
            at: [root], matching: { _ in true }, limit: 2, prioritizeLargest: true
        )
        XCTAssertEqual(
            Set(largest.candidates.map(\.url.lastPathComponent)),
            ["huge.bin", "large.bin"],
            "prioritizeLargest must retain the biggest files, not the first enumerated"
        )
    }
}
