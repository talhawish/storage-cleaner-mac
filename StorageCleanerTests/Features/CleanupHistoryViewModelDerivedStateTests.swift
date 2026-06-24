import SwiftData
import XCTest
@testable import StorageCleaner

@MainActor
final class CleanupHistoryViewModelDerivedStateTests: XCTestCase {
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
        date: Date = .now
    ) -> StoredScan {
        let scan = StoredScan(
            date: date,
            durationSeconds: 10,
            scannedItemCount: 1,
            reclaimableBytes: 1_000
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
        items: Int
    ) -> StoredCleanupAction {
        let action = StoredCleanupAction(
            kindRaw: kind.rawValue,
            bytesReclaimed: bytes,
            itemCount: items
        )
        action.scan = scan
        context.insert(action)
        return action
    }

    private static func makeSummary(
        scanID: Int,
        date: Date,
        kind: StorageFindingKind,
        bytes: Int64,
        items: Int
    ) -> CleanupScanSummary {
        let category = CleanupCategorySummary(
            kind: kind,
            bytesReclaimed: bytes,
            itemCount: items,
            samplePaths: []
        )
        return CleanupScanSummary(
            scanID: scanID,
            date: date,
            durationSeconds: 5,
            scannedItemCount: 1,
            categoriesFound: 1,
            reclaimableBytes: 100,
            categories: [category],
            totalItemsCleaned: items,
            totalBytesCleaned: bytes,
            freeBytesBefore: 0,
            freeBytesAfter: 0,
            volumeTotalBytes: 0
        )
    }

    func testTotalScansWithCleanupCountsOnlyCleanedScans() throws {
        let fixture = makeFixture()
        let cleanedScan = makeScan(in: fixture.context)
        _ = makeScan(in: fixture.context)
        makeCleanup(
            in: fixture.context,
            scan: cleanedScan,
            kind: .xcodeArtifacts,
            bytes: 100,
            items: 1
        )
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.totalScans, 2)
        XCTAssertEqual(viewModel.totalScansWithCleanup, 1)
    }

    func testFirstAndLastCleanupDatesBracketTheHistory() throws {
        let fixture = makeFixture()
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = firstDate.addingTimeInterval(120)

        let firstScan = makeScan(in: fixture.context, date: firstDate)
        let secondScan = makeScan(in: fixture.context, date: secondDate)
        makeCleanup(in: fixture.context, scan: firstScan, kind: .xcodeArtifacts, bytes: 1, items: 1)
        makeCleanup(in: fixture.context, scan: secondScan, kind: .junkFiles, bytes: 1, items: 1)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.firstCleanupDate, firstDate)
        XCTAssertEqual(viewModel.lastCleanupDate, secondDate)
    }

    func testLargestCleanupPicksTheScanWithMostBytes() throws {
        let fixture = makeFixture()
        let smallScan = makeScan(in: fixture.context, date: Date(timeIntervalSince1970: 100))
        let largeScan = makeScan(in: fixture.context, date: Date(timeIntervalSince1970: 200))
        let tinyScan = makeScan(in: fixture.context, date: Date(timeIntervalSince1970: 300))
        makeCleanup(in: fixture.context, scan: smallScan, kind: .xcodeArtifacts, bytes: 500, items: 1)
        makeCleanup(in: fixture.context, scan: largeScan, kind: .junkFiles, bytes: 9_000, items: 4)
        makeCleanup(in: fixture.context, scan: tinyScan, kind: .nodeDependencies, bytes: 100, items: 1)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        let largest = try XCTUnwrap(viewModel.largestCleanup)
        XCTAssertEqual(largest.bytes, 9_000)
        XCTAssertEqual(largest.items, 4)
        XCTAssertEqual(largest.date, Date(timeIntervalSince1970: 200))
    }

    func testLargestCleanupIsNilWhenNoScanCleanedAnything() throws {
        let fixture = makeFixture()
        _ = makeScan(in: fixture.context)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertNil(viewModel.largestCleanup)
    }

    func testTopCategoriesAggregatesAndSortsByBytesDescending() throws {
        let fixture = makeFixture()
        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = firstDate.addingTimeInterval(60)

        let firstScan = makeScan(in: fixture.context, date: firstDate)
        makeCleanup(in: fixture.context, scan: firstScan, kind: .xcodeArtifacts, bytes: 5_000, items: 3)
        makeCleanup(in: fixture.context, scan: firstScan, kind: .junkFiles, bytes: 1_000, items: 1)

        let secondScan = makeScan(in: fixture.context, date: secondDate)
        makeCleanup(in: fixture.context, scan: secondScan, kind: .xcodeArtifacts, bytes: 2_000, items: 2)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.topCategories.count, 2)
        let xcode = try XCTUnwrap(viewModel.topCategories.first)
        XCTAssertEqual(xcode.kind, .xcodeArtifacts)
        XCTAssertEqual(xcode.bytesReclaimed, 7_000)
        XCTAssertEqual(xcode.itemCount, 5)
        XCTAssertEqual(xcode.scanCount, 2)
        XCTAssertEqual(xcode.share, 7_000.0 / 8_000.0, accuracy: 0.0001)
    }

    func testTopCategoriesRespectsLimit() throws {
        let fixture = makeFixture()
        let scan = makeScan(in: fixture.context)
        makeCleanup(in: fixture.context, scan: scan, kind: .xcodeArtifacts, bytes: 100, items: 1)
        makeCleanup(in: fixture.context, scan: scan, kind: .junkFiles, bytes: 80, items: 1)
        makeCleanup(in: fixture.context, scan: scan, kind: .nodeDependencies, bytes: 60, items: 1)
        makeCleanup(in: fixture.context, scan: scan, kind: .rustDependencies, bytes: 40, items: 1)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertEqual(viewModel.topCategories.count, 4)
        XCTAssertEqual(
            viewModel.topCategories.map(\.kind),
            [.xcodeArtifacts, .junkFiles, .nodeDependencies, .rustDependencies]
        )
    }

    func testTopCategoriesIsEmptyWhenNoCleanup() throws {
        let fixture = makeFixture()
        _ = makeScan(in: fixture.context)
        try fixture.context.save()

        let scans = try fixture.context.fetch(FetchDescriptor<StoredScan>())
        let viewModel = CleanupHistoryViewModel()
        viewModel.update(with: scans)

        XCTAssertTrue(viewModel.topCategories.isEmpty)
    }

    func testCurrentMonthTotalsOnlyCountsScansInTheCurrentCalendarMonth() {
        let calendar = Calendar.current
        let now = Date()
        let thisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? thisMonth
        let ancient = Date(timeIntervalSince1970: 0)

        let summaries = [
            Self.makeSummary(
                scanID: 1,
                date: thisMonth.addingTimeInterval(60),
                kind: .xcodeArtifacts,
                bytes: 1_000,
                items: 2
            ),
            Self.makeSummary(scanID: 2, date: lastMonth, kind: .junkFiles, bytes: 5_000, items: 3),
            Self.makeSummary(scanID: 3, date: ancient, kind: .nodeDependencies, bytes: 9_000, items: 4)
        ]

        let (bytes, items) = CleanupHistoryViewModel.currentMonthTotals(in: summaries)
        XCTAssertEqual(bytes, 1_000)
        XCTAssertEqual(items, 2)
    }
}
