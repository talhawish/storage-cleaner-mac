import SwiftData
import XCTest
@testable import StorageCleaner

@MainActor
final class ScanHistoryStoreTests: XCTestCase {
    /// Held for the test's lifetime: a `ModelContext` does not strongly retain its
    /// `ModelContainer`, so without this the container would deallocate as soon as
    /// `makeStore()` returns, leaving the context orphaned and crashing on first use.
    private var container: ModelContainer?

    override func tearDownWithError() throws {
        container = nil
    }

    private func makeStore() -> (store: SwiftDataScanHistoryStore, context: ModelContext) {
        let container = PersistenceController.makeInMemory()
        self.container = container
        let context = container.mainContext
        return (SwiftDataScanHistoryStore(context: context), context)
    }

    func testRecordCompletedScanPersistsScanAndFindings() throws {
        let (store, context) = makeStore()
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

        store.recordCompletedScan(snapshot)

        let scans = try context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 1)
        let scan = try XCTUnwrap(scans.first)
        XCTAssertEqual(scan.scannedItemCount, 12)
        XCTAssertEqual(scan.reclaimableBytes, 2_048)
        XCTAssertEqual(scan.durationSeconds, 5, accuracy: 0.001)
        XCTAssertEqual(scan.findings.count, 1)
        XCTAssertEqual(scan.findings.first?.kind, .xcodeArtifacts)
    }

    func testEmptyScanIsNotRecorded() throws {
        let (store, context) = makeStore()

        store.recordCompletedScan(ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(1)))

        XCTAssertTrue(try context.fetch(FetchDescriptor<StoredScan>()).isEmpty)
    }

    func testCleanupActionsAttachToMostRecentScan() throws {
        let (store, context) = makeStore()
        store.recordCompletedScan(
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

        store.recordCleanupActions([CleanupAuditEntry(kind: .trash, bytesReclaimed: 10, itemCount: 1)])

        let actions = try context.fetch(FetchDescriptor<StoredCleanupAction>())
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.bytesReclaimed, 10)
        XCTAssertNotNil(actions.first?.scan)

        let scans = try context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.first?.cleanupActions.count, 1)
    }

    func testDuplicateGroupsSurvivePersistenceRoundTrip() throws {
        let (store, context) = makeStore()
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

        store.recordCompletedScan(snapshot)

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<StoredFinding>()).first)
        let restored = try XCTUnwrap(stored.toStorageFinding())
        XCTAssertEqual(restored.duplicateGroups.count, 1)
        XCTAssertEqual(restored.duplicateGroups.first?.contentHash, "abc123")
        XCTAssertEqual(restored.duplicateGroups.first?.files.count, 2)
        XCTAssertEqual(restored.duplicateGroups.first?.keepURL, keep)
    }

    func testEmptyCleanupActionsAreNoOp() throws {
        let (store, context) = makeStore()

        store.recordCleanupActions([])

        XCTAssertTrue(try context.fetch(FetchDescriptor<StoredCleanupAction>()).isEmpty)
    }
}
