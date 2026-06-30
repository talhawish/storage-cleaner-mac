import SwiftData
import XCTest
@testable import StorageCleaner

@MainActor
final class ScanHistoryStoreCleanupActionTests: XCTestCase {
    private struct StoreFixture {
        let container: ModelContainer
        let store: SwiftDataScanHistoryStore
        let context: ModelContext
    }

    private func makeStore() -> StoreFixture {
        let container = PersistenceController.makeInMemory()
        let context = container.mainContext
        return StoreFixture(
            container: container,
            store: SwiftDataScanHistoryStore(context: context),
            context: context
        )
    }

    private func recordMinimalScan(in store: SwiftDataScanHistoryStore) {
        store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .trash,
                        domain: .trash,
                        bytes: 1,
                        itemCount: 1,
                        safety: .review,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/x")]
                    )
                ],
                scannedItemCount: 1,
                duration: .seconds(1)
            ),
            disk: .unavailable
        )
    }

    func testEmptyCleanupActionsAreNoOp() throws {
        let fixture = makeStore()

        fixture.store.recordCleanupActions([], disk: .unavailable)

        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).isEmpty)
    }

    func testInvalidCleanupActionsAreNotPersisted() throws {
        let fixture = makeStore()
        recordMinimalScan(in: fixture.store)

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(kind: .trash, bytesReclaimed: -1, itemCount: 1),
            CleanupAuditEntry(kind: .junkFiles, bytesReclaimed: 100, itemCount: 0)
        ], disk: .unavailable)

        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).isEmpty)
        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.cleanedBytes, 0)
    }

    func testCleanupBeforeFirstScanCreatesVisibleCleanupOnlyHistoryRecord() throws {
        let fixture = makeStore()
        let disk = ScanDiskSnapshot(totalBytes: 1_000_000, freeBytes: 400_000)

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(
                kind: .browserCaches,
                bytesReclaimed: 1_024,
                itemCount: 1,
                samplePaths: [URL(filePath: "/tmp/browser-cache")]
            )
        ], disk: disk)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let scan = try XCTUnwrap(scans.first)
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scan.findings.count, 0)
        XCTAssertEqual(scan.scannedItemCount, 0)
        XCTAssertEqual(scan.cleanedBytes, 1_024)
        XCTAssertEqual(scan.volumeTotalBytes, 1_000_000)
        XCTAssertEqual(scan.freeBytesBefore, 0)
        XCTAssertEqual(scan.freeBytesAfter, 400_000)
        XCTAssertEqual(scan.cleanupActions.count, 1)
        XCTAssertEqual(scan.cleanupActions.first?.kindRaw, StorageFindingKind.browserCaches.rawValue)
    }

    func testCleanupActionsCapAndDeduplicateSamplePathsAtStoreBoundary() throws {
        let fixture = makeStore()
        recordMinimalScan(in: fixture.store)
        let paths = [
            URL(filePath: "/tmp/a"),
            URL(filePath: "/tmp/a/"),
            URL(filePath: "/tmp/b"),
            URL(filePath: "/tmp/c"),
            URL(filePath: "/tmp/d"),
            URL(filePath: "/tmp/e"),
            URL(filePath: "/tmp/f")
        ]

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(kind: .trash, bytesReclaimed: 100, itemCount: 6, samplePaths: paths)
        ], disk: .unavailable)

        let action = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).first)
        XCTAssertEqual(action.samplePaths, [
            URL(filePath: "/tmp/a"),
            URL(filePath: "/tmp/b"),
            URL(filePath: "/tmp/c"),
            URL(filePath: "/tmp/d"),
            URL(filePath: "/tmp/e")
        ])
    }

    func testSamplePathsArePersistedOnCleanupActions() throws {
        let fixture = makeStore()
        fixture.store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .xcodeArtifacts,
                        domain: .appleDevelopment,
                        bytes: 1_024,
                        itemCount: 1,
                        safety: .safe,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/DerivedData")]
                    )
                ],
                scannedItemCount: 1,
                duration: .seconds(1)
            ),
            disk: .unavailable
        )

        let paths = [
            URL(filePath: "/tmp/DerivedData/ProjectA"),
            URL(filePath: "/tmp/DerivedData/ProjectB")
        ]
        fixture.store.recordCleanupActions([
            CleanupAuditEntry(
                kind: .xcodeArtifacts,
                bytesReclaimed: 1_024,
                itemCount: 2,
                samplePaths: paths
            )
        ], disk: .unavailable)

        let action = try XCTUnwrap(
            try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).first
        )
        XCTAssertEqual(action.samplePaths, paths)
    }

    func testCleanupActionsUpdateScanCleanedBytes() throws {
        let fixture = makeStore()
        fixture.store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .nodeDependencies,
                        domain: .webDevelopment,
                        bytes: 5_000,
                        itemCount: 2,
                        safety: .safe,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/node_modules")]
                    ),
                    StorageFinding(
                        kind: .junkFiles,
                        domain: .otherCaches,
                        bytes: 2_500,
                        itemCount: 1,
                        safety: .safe,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/junk")]
                    )
                ],
                scannedItemCount: 3,
                duration: .seconds(2)
            ),
            disk: .unavailable
        )

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(
                kind: .nodeDependencies,
                bytesReclaimed: 4_000,
                itemCount: 1,
                samplePaths: [URL(filePath: "/tmp/node_modules")]
            )
        ], disk: .unavailable)
        fixture.store.recordCleanupActions([
            CleanupAuditEntry(
                kind: .junkFiles,
                bytesReclaimed: 1_000,
                itemCount: 1,
                samplePaths: [URL(filePath: "/tmp/junk")]
            )
        ], disk: .unavailable)

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.cleanedBytes, 5_000)
    }

    func testCleanupActionsClampScanCleanedBytesWhenExistingTotalWouldOverflow() throws {
        let fixture = makeStore()
        recordMinimalScan(in: fixture.store)

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        scan.cleanedBytes = Int64.max - 10

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(kind: .trash, bytesReclaimed: 100, itemCount: 1)
        ], disk: .unavailable)

        XCTAssertEqual(scan.cleanedBytes, Int64.max)
    }

    func testCleanupActionsClampScanCleanedBytesWhenNewEntriesWouldOverflow() throws {
        let fixture = makeStore()
        recordMinimalScan(in: fixture.store)

        fixture.store.recordCleanupActions([
            CleanupAuditEntry(kind: .trash, bytesReclaimed: Int64.max, itemCount: 1),
            CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)
        ], disk: .unavailable)

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.cleanedBytes, Int64.max)
    }

    func testCleanedBytesRemainZeroWhenNoActionsRecorded() throws {
        let fixture = makeStore()
        fixture.store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .xcodeArtifacts,
                        domain: .appleDevelopment,
                        bytes: 1_000,
                        itemCount: 1,
                        safety: .safe,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/DerivedData")]
                    )
                ],
                scannedItemCount: 1,
                duration: .seconds(1)
            ),
            disk: .unavailable
        )

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.cleanedBytes, 0)
    }

    func testCleanupActionsRecordFreeBytesAfter() throws {
        let fixture = makeStore()
        let disk = ScanDiskSnapshot(totalBytes: 1_000_000_000_000, freeBytes: 500_000_000_000)
        fixture.store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .xcodeArtifacts,
                        domain: .appleDevelopment,
                        bytes: 1_000,
                        itemCount: 1,
                        safety: .safe,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/DerivedData")]
                    )
                ],
                scannedItemCount: 1,
                duration: .seconds(1)
            ),
            disk: disk
        )

        let after = ScanDiskSnapshot(totalBytes: 1_000_000_000_000, freeBytes: 600_000_000_000)
        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .xcodeArtifacts, bytesReclaimed: 1_000, itemCount: 1)],
            disk: after
        )

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.freeBytesBefore, 500_000_000_000)
        XCTAssertEqual(scan.freeBytesAfter, 600_000_000_000)
    }

    func testCleanupActionsKeepFreeBytesAfterZeroWhenDiskUnavailable() throws {
        let fixture = makeStore()
        recordMinimalScan(in: fixture.store)

        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)],
            disk: .unavailable
        )

        let scan = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredScan>()).first)
        XCTAssertEqual(scan.freeBytesAfter, 0)
    }
}
