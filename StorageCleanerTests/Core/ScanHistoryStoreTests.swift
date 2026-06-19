import SwiftData
import XCTest
@testable import StorageCleaner

@MainActor
final class ScanHistoryStoreTests: XCTestCase {
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

    func testRecordCompletedScanPersistsScanAndFindings() throws {
        let fixture = makeStore()
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .xcodeArtifacts,
                    domain: .appleDevelopment,
                    bytes: 2_048,
                    itemCount: 3,
                    safety: .safe,
                    examples: ["DerivedData"],
                    filePaths: [URL(filePath: "/tmp/DerivedData")]
                )
            ],
            scannedItemCount: 12,
            duration: .seconds(5)
        )

        fixture.store.recordCompletedScan(snapshot)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 1)
        let scan = try XCTUnwrap(scans.first)
        XCTAssertEqual(scan.scannedItemCount, 12)
        XCTAssertEqual(scan.reclaimableBytes, 2_048)
        XCTAssertEqual(scan.durationSeconds, 5, accuracy: 0.001)
        XCTAssertEqual(scan.findings.count, 1)
        XCTAssertEqual(scan.findings.first?.kind, .xcodeArtifacts)
    }

    func testEmptyScanIsNotRecorded() throws {
        let fixture = makeStore()

        fixture.store.recordCompletedScan(ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(1)))

        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredScan>()).isEmpty)
    }

    func testCleanupActionsAttachToMostRecentScan() throws {
        let fixture = makeStore()
        fixture.store.recordCompletedScan(
            ScanSnapshot(
                findings: [
                    StorageFinding(
                        kind: .trash,
                        domain: .trash,
                        bytes: 10,
                        itemCount: 1,
                        safety: .review,
                        examples: [],
                        filePaths: [URL(filePath: "/tmp/x")]
                    )
                ],
                scannedItemCount: 1,
                duration: .seconds(1)
            )
        )

        fixture.store.recordCleanupActions([CleanupAuditEntry(kind: .trash, bytesReclaimed: 10, itemCount: 1)])

        let actions = try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>())
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.bytesReclaimed, 10)
        XCTAssertNotNil(actions.first?.scan)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.first?.cleanupActions.count, 1)
    }

    func testDuplicateGroupsSurvivePersistenceRoundTrip() throws {
        let fixture = makeStore()
        let keep = URL(filePath: "/tmp/keep.png")
        let dupe = URL(filePath: "/tmp/dupe.png")
        let group = DuplicateGroup(
            contentHash: "abc123",
            files: [
                DuplicateFile(url: keep, bytes: 2_048, modifiedAt: nil),
                DuplicateFile(url: dupe, bytes: 2_048, modifiedAt: nil)
            ],
            keepURL: keep
        )
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .duplicatePhotos,
                    domain: .photos,
                    bytes: 2_048,
                    itemCount: 1,
                    safety: .review,
                    examples: [],
                    filePaths: [dupe],
                    duplicateGroups: [group]
                )
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )

        fixture.store.recordCompletedScan(snapshot)

        let stored = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredFinding>()).first)
        let restored = try XCTUnwrap(stored.toStorageFinding())
        XCTAssertEqual(restored.duplicateGroups.count, 1)
        XCTAssertEqual(restored.duplicateGroups.first?.contentHash, "abc123")
        XCTAssertEqual(restored.duplicateGroups.first?.files.count, 2)
        XCTAssertEqual(restored.duplicateGroups.first?.keepURL, keep)
    }

    func testEmptyCleanupActionsAreNoOp() throws {
        let fixture = makeStore()

        fixture.store.recordCleanupActions([])

        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).isEmpty)
    }
}
