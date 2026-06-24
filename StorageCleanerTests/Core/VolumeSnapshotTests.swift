import XCTest
@testable import StorageCleaner

final class VolumeSnapshotTests: XCTestCase {
    func testInitClampsNegativeValuesToZero() {
        let snapshot = VolumeSnapshot(totalBytes: -1, usedBytes: -5, freeBytes: -10)
        XCTAssertEqual(snapshot.totalBytes, 0)
        XCTAssertEqual(snapshot.usedBytes, 0)
        XCTAssertEqual(snapshot.freeBytes, 0)
        XCTAssertFalse(snapshot.isAvailable)
    }

    func testUsageFractionReflectsUsedVersusTotal() {
        let snapshot = VolumeSnapshot(totalBytes: 1_000, usedBytes: 250, freeBytes: 750)
        XCTAssertEqual(snapshot.usageFraction, 0.25, accuracy: 0.0001)
    }

    func testUsageFractionClampsToBounds() {
        // Used > total should still resolve to 1.0, not overflow.
        let oversized = VolumeSnapshot(totalBytes: 1_000, usedBytes: 5_000, freeBytes: 0)
        XCTAssertEqual(oversized.usageFraction, 1.0)

        // 0 capacity reports 0 so the UI doesn't render a NaN%.
        let empty = VolumeSnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0)
        XCTAssertEqual(empty.usageFraction, 0)
    }

    func testProjectedFreeBytesAddsReclaimable() {
        let snapshot = VolumeSnapshot(totalBytes: 1_000, usedBytes: 600, freeBytes: 400)
        XCTAssertEqual(snapshot.projectedFreeBytes(reclaiming: 200), 600)
    }

    func testProjectedFreeBytesClampsAtTotalCapacity() {
        // Don't claim more than the volume can hold, even if cleanup found "everything".
        let snapshot = VolumeSnapshot(totalBytes: 1_000, usedBytes: 900, freeBytes: 100)
        XCTAssertEqual(snapshot.projectedFreeBytes(reclaiming: 5_000), 1_000)
    }

    func testProjectedFreeBytesWithZeroReclaimableReturnsCurrentFree() {
        let snapshot = VolumeSnapshot(totalBytes: 1_000, usedBytes: 600, freeBytes: 400)
        XCTAssertEqual(snapshot.projectedFreeBytes(reclaiming: 0), 400)
    }

    func testProjectedUsageFractionDropsAsBytesAreReclaimed() {
        let snapshot = VolumeSnapshot(totalBytes: 1_000, usedBytes: 800, freeBytes: 200)
        XCTAssertEqual(snapshot.projectedUsageFraction(reclaiming: 300), 0.5, accuracy: 0.0001)
    }

    func testUnavailableSnapshotHasNoCapacity() {
        let snapshot = VolumeSnapshot.unavailable
        XCTAssertFalse(snapshot.isAvailable)
        XCTAssertEqual(snapshot.usageFraction, 0)
        XCTAssertEqual(snapshot.projectedFreeBytes(reclaiming: 1_000), 0)
    }
}
