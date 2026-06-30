import SwiftData
import XCTest
@testable import StorageCleaner

@MainActor
final class CleanupHistoryViewModelTests: XCTestCase {
    private struct Fixture {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeFixture() -> Fixture {
        let container = PersistenceController.makeInMemory()
        return Fixture(container: container, context: container.mainContext)
    }

    private func makeScan(
        in context: ModelContext,
        date: Date = .now,
        duration: Double = 10,
        reclaimableBytes: Int64 = 1_000,
        volumeTotalBytes: Int64 = 0,
        freeBytesBefore: Int64 = 0,
        freeBytesAfter: Int64 = 0,
        findingKinds: [StorageFindingKind] = [.xcodeArtifacts]
    ) -> StoredScan {
        let findings = findingKinds.map { kind in
            StoredFinding(from: StorageFinding(
                kind: kind,
                domain: .otherCaches,
                bytes: 500,
                itemCount: 1,
                safety: .safe,
                examples: [],
                filePaths: [URL(filePath: "/tmp/\(kind.rawValue)")]
            ))
        }
        let scan = StoredScan(
            date: date,
            durationSeconds: duration,
            scannedItemCount: findingKinds.count,
            reclaimableBytes: reclaimableBytes,
            volumeTotalBytes: volumeTotalBytes,
            freeBytesBefore: freeBytesBefore,
            freeBytesAfter: freeBytesAfter,
            findings: findings
        )
        context.insert(scan)
        return scan
    }

    @discardableResult
    private func makeCleanup(
        in context: ModelContext,
        scan: StoredScan,
        kind: StorageFindingKind,
        bytes: Int64,
        items: Int,
        paths: [URL] = []
    ) -> StoredCleanupAction {
        let action = StoredCleanupAction(
            kindRaw: kind.rawValue,
            bytesReclaimed: bytes,
            itemCount: items,
            samplePaths: paths
        )
        action.scan = scan
        context.insert(action)
        return action
    }

    func testEmptyHistoryLeavesTotalsAtZero() {
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: [])

        XCTAssertEqual(viewModel.summaries, [])
        XCTAssertEqual(viewModel.totalScans, 0)
        XCTAssertEqual(viewModel.totalBytesReclaimed, 0)
        XCTAssertEqual(viewModel.totalItemsReclaimed, 0)
        XCTAssertNil(viewModel.lastCleanupDate)
    }

    func testUpdateAggregatesTotalsAcrossScans() throws {
        let fixture = makeFixture()

        let firstDate = Date(timeIntervalSince1970: 1_000_000)
        let secondDate = firstDate.addingTimeInterval(60)

        let firstScan = makeScan(
            in: fixture.context,
            date: firstDate,
            duration: 5,
            reclaimableBytes: 10_000,
            findingKinds: [.xcodeArtifacts, .nodeDependencies]
        )
        makeCleanup(
            in: fixture.context,
            scan: firstScan,
            kind: .xcodeArtifacts,
            bytes: 4_000,
            items: 2
        )
        makeCleanup(
            in: fixture.context,
            scan: firstScan,
            kind: .nodeDependencies,
            bytes: 1_000,
            items: 1
        )

        let secondScan = makeScan(
            in: fixture.context,
            date: secondDate,
            duration: 7,
            reclaimableBytes: 8_000,
            findingKinds: [.junkFiles]
        )
        makeCleanup(
            in: fixture.context,
            scan: secondScan,
            kind: .junkFiles,
            bytes: 2_500,
            items: 3
        )

        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.totalScans, 2)
        XCTAssertEqual(viewModel.totalBytesReclaimed, 7_500)
        XCTAssertEqual(viewModel.totalItemsReclaimed, 6)
        XCTAssertEqual(viewModel.lastCleanupDate, secondDate)
    }

    func testSummarySortsCategoriesByBytesReclaimedDescending() throws {
        let fixture = makeFixture()
        let date = Date(timeIntervalSince1970: 2_000_000)
        let kinds: [StorageFindingKind] = [.xcodeArtifacts, .junkFiles, .nodeDependencies]
        let scan = makeScan(in: fixture.context, date: date, findingKinds: kinds)

        // Insert out of order to prove the summary re-sorts.
        makeCleanup(in: fixture.context, scan: scan, kind: .xcodeArtifacts, bytes: 100, items: 1)
        makeCleanup(in: fixture.context, scan: scan, kind: .junkFiles, bytes: 9_000, items: 1)
        makeCleanup(in: fixture.context, scan: scan, kind: .nodeDependencies, bytes: 2_500, items: 1)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertEqual(summary.categories.map(\.kind), [.junkFiles, .nodeDependencies, .xcodeArtifacts])
        XCTAssertEqual(summary.totalBytesCleaned, 11_600)
        XCTAssertEqual(summary.totalItemsCleaned, 3)
        XCTAssertEqual(summary.categoriesFound, 3)
    }

    func testSummarySkipsActionsWithUnknownKind() throws {
        let fixture = makeFixture()
        let scan = makeScan(in: fixture.context)
        let bogus = StoredCleanupAction(
            kindRaw: "thisKindDoesNotExist",
            bytesReclaimed: 9_999,
            itemCount: 7
        )
        bogus.scan = scan
        fixture.context.insert(bogus)
        makeCleanup(in: fixture.context, scan: scan, kind: .junkFiles, bytes: 1_000, items: 1)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertEqual(summary.categories.count, 1)
        XCTAssertEqual(summary.totalBytesCleaned, 1_000)
        XCTAssertEqual(summary.totalItemsCleaned, 1)
    }

    func testSummarySkipsMalformedCleanupActions() throws {
        let fixture = makeFixture()
        let scan = makeScan(in: fixture.context)
        makeCleanup(in: fixture.context, scan: scan, kind: .junkFiles, bytes: 1_000, items: 1)

        let negativeBytes = StoredCleanupAction(
            kindRaw: StorageFindingKind.trash.rawValue,
            bytesReclaimed: -100,
            itemCount: 1
        )
        negativeBytes.scan = scan
        fixture.context.insert(negativeBytes)

        let zeroItems = StoredCleanupAction(
            kindRaw: StorageFindingKind.browserCaches.rawValue,
            bytesReclaimed: 500,
            itemCount: 0
        )
        zeroItems.scan = scan
        fixture.context.insert(zeroItems)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertEqual(summary.categories.map(\.kind), [.junkFiles])
        XCTAssertEqual(summary.totalBytesCleaned, 1_000)
        XCTAssertEqual(summary.totalItemsCleaned, 1)
    }

    func testSummaryWithoutCleanupMarksHasCleanupFalse() throws {
        let fixture = makeFixture()
        _ = makeScan(in: fixture.context)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertFalse(summary.hasCleanup)
        XCTAssertEqual(summary.totalBytesCleaned, 0)
        XCTAssertEqual(summary.totalItemsCleaned, 0)
    }

    func testSummaryPreservesSamplePaths() throws {
        let fixture = makeFixture()
        let scan = makeScan(in: fixture.context)
        let paths = [
            URL(filePath: "/tmp/DerivedData/ProjectA"),
            URL(filePath: "/tmp/DerivedData/ProjectB")
        ]
        makeCleanup(
            in: fixture.context,
            scan: scan,
            kind: .xcodeArtifacts,
            bytes: 2_000,
            items: 2,
            paths: paths
        )
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        let category = try XCTUnwrap(summary.categories.first)
        XCTAssertEqual(category.samplePaths, paths)
    }

    func testLastCleanupDateIgnoresScansWithNoCleanup() throws {
        let fixture = makeFixture()
        let early = makeScan(in: fixture.context, date: Date(timeIntervalSince1970: 100))
        _ = makeScan(in: fixture.context, date: Date(timeIntervalSince1970: 300))
        // Only the early scan has cleanup; it should win despite the later scan's date.
        makeCleanup(
            in: fixture.context,
            scan: early,
            kind: .xcodeArtifacts,
            bytes: 1,
            items: 1
        )
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.lastCleanupDate, Date(timeIntervalSince1970: 100))
    }

    func testSummaryExposesDiskSnapshotsWhenPersisted() throws {
        let fixture = makeFixture()
        let scan = makeScan(
            in: fixture.context,
            volumeTotalBytes: 1_000_000_000_000,
            freeBytesBefore: 500_000_000_000,
            freeBytesAfter: 600_000_000_000
        )
        makeCleanup(
            in: fixture.context,
            scan: scan,
            kind: .xcodeArtifacts,
            bytes: 100_000_000_000,
            items: 1
        )
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertTrue(summary.hasDiskSnapshot)
        XCTAssertEqual(summary.freeBytesBefore, 500_000_000_000)
        XCTAssertEqual(summary.freeBytesAfter, 600_000_000_000)
        XCTAssertEqual(summary.freedBytesByCleanup, 100_000_000_000)
    }

    func testSummaryHidesDiskInfoWhenTotalCapacityMissing() throws {
        let fixture = makeFixture()
        // Legacy scan without disk info persisted.
        _ = makeScan(in: fixture.context)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertFalse(summary.hasDiskSnapshot)
        XCTAssertNil(summary.freedBytesByCleanup)
    }

    func testSummaryFreedBytesNilWhenNoCleanup() throws {
        let fixture = makeFixture()
        _ = makeScan(
            in: fixture.context,
            volumeTotalBytes: 1_000_000_000_000,
            freeBytesBefore: 500_000_000_000,
            freeBytesAfter: 0
        )
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let summary = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertTrue(summary.hasDiskSnapshot)
        XCTAssertNil(summary.freedBytesByCleanup)
    }
}
