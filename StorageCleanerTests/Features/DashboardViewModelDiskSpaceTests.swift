import XCTest
@testable import StorageCleaner

@MainActor
final class DashboardViewModelDiskSpaceTests: XCTestCase {
    func testInitPublishesInitialVolumeSnapshot() async {
        let reader = StaticDiskSpaceReader(
            snapshot: VolumeSnapshot(totalBytes: 2_000, usedBytes: 1_000, freeBytes: 1_000)
        )
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            diskSpaceReader: reader
        )

        for _ in 0..<20 where !viewModel.volumeSnapshot.isAvailable {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.volumeSnapshot.totalBytes, 2_000)
        XCTAssertEqual(viewModel.volumeSnapshot.freeBytes, 1_000)
        XCTAssertEqual(viewModel.volumeSnapshot.usageFraction, 0.5, accuracy: 0.0001)
    }

    func testTotalReclaimableBytesExposesSafeAndReviewTotals() async {
        let snapshot = ScanSnapshot(
            findings: [
                finding(.xcodeArtifacts, .appleDevelopment, bytes: 800, items: 1, safety: .safe),
                finding(.largeVideos, .media, bytes: 200, items: 1, safety: .review)
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            diskSpaceReader: StaticDiskSpaceReader(
                snapshot: VolumeSnapshot(totalBytes: 10_000, usedBytes: 7_000, freeBytes: 3_000)
            )
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results { await Task.yield() }

        XCTAssertEqual(viewModel.totalReclaimableBytes, 1_000)
        XCTAssertEqual(viewModel.projectedFreeBytes, 4_000)
        XCTAssertEqual(viewModel.projectedUsageFraction ?? 0, 0.6, accuracy: 0.0001)
    }

    func testProjectedBytesAreNilWhenVolumeUnavailable() async {
        let snapshot = ScanSnapshot(
            findings: [
                finding(.xcodeArtifacts, .appleDevelopment, bytes: 100, items: 1, safety: .safe)
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            diskSpaceReader: StaticDiskSpaceReader(snapshot: .unavailable)
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results { await Task.yield() }

        XCTAssertNil(viewModel.projectedFreeBytes)
        XCTAssertNil(viewModel.projectedUsageFraction)
    }

    func testFullScanRecordsDiskSnapshotInHistory() async {
        let reader = StaticDiskSpaceReader(
            snapshot: VolumeSnapshot(totalBytes: 10_000, usedBytes: 6_000, freeBytes: 4_000)
        )
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            diskSpaceReader: reader,
            historyStore: store
        )

        // Wait for the init-time refresh to publish.
        for _ in 0..<50 where !viewModel.volumeSnapshot.isAvailable {
            await Task.yield()
        }

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results { await Task.yield() }
        for _ in 0..<20 where store.recordedScans.isEmpty { await Task.yield() }

        let recorded = try? XCTUnwrap(store.recordedScanDisks.first)
        XCTAssertEqual(recorded?.totalBytes, 10_000)
        XCTAssertEqual(recorded?.freeBytes, 4_000)
    }

    func testDeleteRefreshesVolumeAndRecordsFreeBytesAfter() async {
        let file = URL(filePath: "/tmp/delete-me")
        let snapshot = ScanSnapshot(
            findings: [
                finding(.largeFiles, .media, bytes: 100, items: 1, safety: .safe)
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
        let reader = MutableDiskSpaceReader(
            snapshots: [
                VolumeSnapshot(totalBytes: 10_000, usedBytes: 6_000, freeBytes: 4_000),
                VolumeSnapshot(totalBytes: 10_000, usedBytes: 5_900, freeBytes: 4_100)
            ]
        )
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: [file: 100]),
            diskSpaceReader: reader,
            historyStore: store
        )

        // Wait for the init-time refresh to publish the first snapshot.
        for _ in 0..<200 where !viewModel.volumeSnapshot.isAvailable {
            await Task.yield()
        }

        viewModel.startScan()
        for _ in 0..<200 where viewModel.phase != .results { await Task.yield() }
        for _ in 0..<200 where store.recordedScans.isEmpty { await Task.yield() }

        _ = await viewModel.deleteFiles([file])

        // Let the post-cleanup volume refresh publish before we assert.
        for _ in 0..<500 where viewModel.volumeSnapshot.freeBytes < 4_100 {
            await Task.yield()
        }
        for _ in 0..<200 where store.recordedCleanupDisks.isEmpty { await Task.yield() }

        XCTAssertEqual(store.recordedCleanupDisks.count, 1)
        let after = try? XCTUnwrap(store.recordedCleanupDisks.first)
        XCTAssertEqual(after?.freeBytes, 4_100)
    }

    private func finding(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        items: Int,
        safety: CleanupSafety
    ) -> StorageFinding {
        StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: items,
            safety: safety,
            examples: [],
            filePaths: []
        )
    }
}

/// Test-only `DiskSpaceReading` that returns a single snapshot every call.
struct StaticDiskSpaceReader: DiskSpaceReading {
    let snapshot: VolumeSnapshot

    func currentVolume(at path: URL) async -> VolumeSnapshot { snapshot }
}

/// Test-only `DiskSpaceReading` that yields a different snapshot on each call
/// so cleanup paths can be exercised end-to-end.
final class MutableDiskSpaceReader: DiskSpaceReading, @unchecked Sendable {
    private var snapshots: [VolumeSnapshot]
    private var index = 0

    init(snapshots: [VolumeSnapshot]) {
        self.snapshots = snapshots
    }

    func currentVolume(at path: URL) async -> VolumeSnapshot {
        let next = snapshots[min(index, snapshots.count - 1)]
        index += 1
        return next
    }
}
