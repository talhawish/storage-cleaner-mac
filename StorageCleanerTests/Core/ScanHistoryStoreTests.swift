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

    private func recordMinimalScan(in store: SwiftDataScanHistoryStore) async {
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
        await store.flush()
    }

    func testRecordCompletedScanPersistsScanAndFindings() async throws {
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
        let disk = ScanDiskSnapshot(totalBytes: 1_000_000_000_000, freeBytes: 500_000_000_000)

        fixture.store.recordCompletedScan(snapshot, disk: disk)
        await fixture.store.flush()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 1)
        let scan = try XCTUnwrap(scans.first)
        XCTAssertEqual(scan.scannedItemCount, 12)
        XCTAssertEqual(scan.reclaimableBytes, 2_048)
        XCTAssertEqual(scan.durationSeconds, 5, accuracy: 0.001)
        XCTAssertEqual(scan.findings.count, 1)
        XCTAssertEqual(scan.findings.first?.kind, .xcodeArtifacts)
        XCTAssertEqual(scan.volumeTotalBytes, 1_000_000_000_000)
        XCTAssertEqual(scan.freeBytesBefore, 500_000_000_000)
        XCTAssertEqual(scan.freeBytesAfter, 0)
    }

    func testEmptyScanIsRecordedAsLatestOverallScan() async throws {
        let fixture = makeStore()

        fixture.store.recordCompletedScan(
            ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(1)),
            disk: .unavailable
        )
        await fixture.store.flush()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let scan = try XCTUnwrap(scans.first)
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scan.recordKind, .overallScan)
        XCTAssertTrue(scan.findings.isEmpty)
    }

    func testNewOverallScanReplacesOlderScanOnlyRecord() async throws {
        let fixture = makeStore()

        await recordMinimalScan(in: fixture.store)
        await recordMinimalScan(in: fixture.store)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 1)
        XCTAssertEqual(scans.first?.recordKind, .overallScan)
        XCTAssertEqual(try fixture.context.fetch(FetchDescriptor<StoredFinding>()).count, 1)
    }

    func testNewOverallScanPreservesRecordsWithCleanupAudit() async throws {
        let fixture = makeStore()

        await recordMinimalScan(in: fixture.store)
        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)],
            disk: .unavailable
        )
        await fixture.store.flush()

        await recordMinimalScan(in: fixture.store)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 2)
        XCTAssertEqual(scans.count(where: { $0.cleanupActions.isEmpty }), 1)
        XCTAssertEqual(scans.count(where: { !$0.cleanupActions.isEmpty }), 1)
    }

    func testCleanupActionsAttachToMostRecentScan() async throws {
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
            ),
            disk: .unavailable
        )
        await fixture.store.flush()

        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .trash, bytesReclaimed: 10, itemCount: 1)],
            disk: .unavailable
        )
        await fixture.store.flush()

        let actions = try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>())
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.bytesReclaimed, 10)
        XCTAssertNotNil(actions.first?.scan)

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.first?.cleanupActions.count, 1)
    }

    func testDuplicateGroupsSurvivePersistenceRoundTrip() async throws {
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

        fixture.store.recordCompletedScan(snapshot, disk: .unavailable)
        await fixture.store.flush()

        let stored = try XCTUnwrap(try fixture.context.fetch(FetchDescriptor<StoredFinding>()).first)
        let restored = try XCTUnwrap(stored.toStorageFinding())
        XCTAssertEqual(restored.duplicateGroups.count, 1)
        XCTAssertEqual(restored.duplicateGroups.first?.contentHash, "abc123")
        XCTAssertEqual(restored.duplicateGroups.first?.files.count, 2)
        XCTAssertEqual(restored.duplicateGroups.first?.keepURL, keep)
    }

    /// The audit trail is best-effort, but a failed write must be observable —
    /// `lastPersistenceError` powers the History screen's warning banner.
    func testSaveFailureSurfacesLastPersistenceError() async {
        let container = PersistenceController.makeInMemory()
        let store = SwiftDataScanHistoryStore(
            context: container.mainContext,
            performSave: { _ in throw CocoaError(.fileWriteNoPermission) }
        )

        await recordMinimalScan(in: store)

        XCTAssertNotNil(store.lastPersistenceError)
    }

    func testSuccessfulSaveClearsPreviousPersistenceError() async {
        final class FlakySave {
            var shouldThrow = true
            func save(_ context: ModelContext) throws {
                if shouldThrow { throw CocoaError(.fileWriteNoPermission) }
                try context.save()
            }
        }
        let container = PersistenceController.makeInMemory()
        let flaky = FlakySave()
        let store = SwiftDataScanHistoryStore(
            context: container.mainContext,
            performSave: { try flaky.save($0) }
        )

        await recordMinimalScan(in: store)
        XCTAssertNotNil(store.lastPersistenceError)

        flaky.shouldThrow = false
        await recordMinimalScan(in: store)
        XCTAssertNil(store.lastPersistenceError)
    }

    /// Durable cleanup audit records remain capped even though scan-only records are replaced.
    func testRetentionPrunesOldestCleanupRecordsPastTheCap() async throws {
        let fixture = makeStore()

        for _ in 0..<(SwiftDataScanHistoryStore.maxStoredScans + 5) {
            await recordMinimalScan(in: fixture.store)
            fixture.store.recordCleanupActions(
                [CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)],
                disk: .unavailable
            )
            await fixture.store.flush()
        }

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, SwiftDataScanHistoryStore.maxStoredScans)
        XCTAssertEqual(
            try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).count,
            SwiftDataScanHistoryStore.maxStoredScans
        )
        let findings = try fixture.context.fetch(FetchDescriptor<StoredFinding>())
        XCTAssertEqual(
            findings.count,
            SwiftDataScanHistoryStore.maxStoredScans,
            "cascade deletes must remove pruned scans' findings"
        )
    }

    func testClearHistoryRemovesEveryScanFindingAndAction() async throws {
        let fixture = makeStore()
        await recordMinimalScan(in: fixture.store)
        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)],
            disk: .unavailable
        )
        await fixture.store.flush()

        fixture.store.clearHistory()
        await fixture.store.flush()

        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredScan>()).isEmpty)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredFinding>()).isEmpty)
        XCTAssertTrue(try fixture.context.fetch(FetchDescriptor<StoredCleanupAction>()).isEmpty)
    }

    /// The scan record and its cleanup actions are written on an ordered
    /// chain: a cleanup enqueued right after a scan must attach to that scan
    /// even though both writes complete asynchronously.
    func testScanThenCleanupOrderingIsPreservedAcrossTheAsyncChain() async throws {
        let fixture = makeStore()

        fixture.store.recordCompletedScan(
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
        fixture.store.recordCleanupActions(
            [CleanupAuditEntry(kind: .trash, bytesReclaimed: 1, itemCount: 1)],
            disk: .unavailable
        )
        await fixture.store.flush()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        XCTAssertEqual(scans.count, 1, "the cleanup must attach to the scan, not create its own record")
        XCTAssertEqual(scans.first?.cleanupActions.count, 1)
    }
}
