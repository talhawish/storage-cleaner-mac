import XCTest
@testable import StorageCleaner

final class DiskSpaceServiceTests: XCTestCase {
    func testSnapshotUsesImportantUsageCapacityForSystemSettingsParity() {
        let snapshot = LiveDiskSpaceService.snapshot(
            totalCapacity: 1_000,
            availableCapacityForImportantUsage: 350,
            availableCapacity: 200
        )

        XCTAssertEqual(snapshot.totalBytes, 1_000)
        XCTAssertEqual(snapshot.usedBytes, 650)
        XCTAssertEqual(snapshot.freeBytes, 350)
    }

    func testSnapshotTreatsZeroImportantUsageCapacityAsValid() {
        let snapshot = LiveDiskSpaceService.snapshot(
            totalCapacity: 1_000,
            availableCapacityForImportantUsage: 0,
            availableCapacity: 200
        )

        XCTAssertEqual(snapshot.usedBytes, 1_000)
        XCTAssertEqual(snapshot.freeBytes, 0)
    }

    func testSnapshotFallsBackToGenericCapacityWhenImportantUsageIsUnavailable() {
        let snapshot = LiveDiskSpaceService.snapshot(
            totalCapacity: 1_000,
            availableCapacityForImportantUsage: nil,
            availableCapacity: 200
        )

        XCTAssertEqual(snapshot.usedBytes, 800)
        XCTAssertEqual(snapshot.freeBytes, 200)
    }

    func testSnapshotClampsInconsistentCapacityValues() {
        let snapshot = LiveDiskSpaceService.snapshot(
            totalCapacity: 1_000,
            availableCapacityForImportantUsage: 1_200,
            availableCapacity: 200
        )

        XCTAssertEqual(snapshot.usedBytes, 0)
        XCTAssertEqual(snapshot.freeBytes, 1_000)
    }

    func testSnapshotIsUnavailableWithoutTotalCapacity() {
        let snapshot = LiveDiskSpaceService.snapshot(
            totalCapacity: 0,
            availableCapacityForImportantUsage: 350,
            availableCapacity: 200
        )

        XCTAssertEqual(snapshot, .unavailable)
    }
}
