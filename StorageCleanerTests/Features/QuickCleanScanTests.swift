import SwiftUI
import XCTest
@testable import StorageCleaner

final class QuickCleanScanTests: XCTestCase {
    private func makeItem(name: String, bytes: Int64, directory: Bool = false) -> QuickCleanItem {
        let url = URL(fileURLWithPath: "/tmp/\(name)", isDirectory: directory)
        return QuickCleanItem(url: url, bytes: bytes)
    }

    private func makeCategory(
        id: String,
        name: String = "Test",
        bytes: [Int64] = [],
        directoryItems: [Int64] = [],
        safety: CleanupSafety = .safe,
        domain: StorageDomain = .otherCaches
    ) -> QuickCleanCategory {
        let items = bytes.map { makeItem(name: "file-\($0)", bytes: $0) }
            + directoryItems.map { makeItem(name: "dir-\($0)", bytes: $0, directory: true) }
        return QuickCleanCategory(
            id: id,
            name: name,
            summary: "",
            icon: "doc.fill",
            tint: .accentColor,
            domain: domain,
            safety: safety,
            items: items
        )
    }

    func testItemIDIsURL() {
        let item = makeItem(name: "a", bytes: 100)
        XCTAssertEqual(item.id, item.url)
    }

    func testCategoryAggregatesBytesAndItemCount() {
        let category = makeCategory(
            id: "x",
            bytes: [100, 200, 300]
        )
        XCTAssertEqual(category.itemCount, 3)
        XCTAssertEqual(category.bytes, 600)
    }

    func testEmptyCategoryIsReported() {
        let category = makeCategory(id: "x")
        XCTAssertEqual(category.itemCount, 0)
        XCTAssertEqual(category.bytes, 0)
        XCTAssertTrue(category.isEmpty)
    }

    func testScanPopulatedCategoriesExcludesEmptyOnes() {
        let populated = makeCategory(id: "a", bytes: [10])
        let empty = makeCategory(id: "b")
        let scan = QuickCleanScan(categories: [populated, empty])
        XCTAssertEqual(scan.totalBytes, 10)
        XCTAssertEqual(scan.totalItemCount, 1)
        XCTAssertEqual(scan.populatedCategories.map(\.id), ["a"])
    }

    func testSelectAllAcrossCategories() {
        let firstCategory = makeCategory(id: "a", bytes: [10, 20])
        let secondCategory = makeCategory(id: "b", bytes: [30])
        let scan = QuickCleanScan(categories: [firstCategory, secondCategory])
        let selection = Set(scan.allItems.map(\.url))
        XCTAssertEqual(scan.selectedBytes(in: selection), 60)
        XCTAssertEqual(scan.selectedItems(in: selection).count, 3)
    }

    func testSelectedBytesIsZeroWhenNothingSelected() {
        let category = makeCategory(id: "a", bytes: [10, 20])
        let scan = QuickCleanScan(categories: [category])
        XCTAssertEqual(scan.selectedBytes(in: []), 0)
    }

    func testCategoryFullySelectedChecksAllItems() {
        let category = makeCategory(id: "a", bytes: [10, 20])
        let selection = Set(category.items.map(\.url))
        XCTAssertTrue(category.items.allSatisfy { selection.contains($0.url) })
    }

    func testCategorySelectedItemsFiltersBySelection() {
        let category = makeCategory(id: "a", bytes: [10, 20, 30])
        let onlyFirst = Set([category.items[0].url])
        XCTAssertEqual(category.selectedItems(in: onlyFirst).count, 1)
    }

    /// This is the regression test for the original Quick Clean bug: multiple
    /// `StorageFinding` values with the same `kind` shared the same `id` and
    /// SwiftUI's `ForEach` only rendered the first one, hiding every other
    /// category. `QuickCleanCategory` uses the option's stable id, so two
    /// different categories with the same kind are still distinct.
    func testCategoriesWithSameKindAreDistinctByID() {
        let firstCategory = QuickCleanCategory(
            id: "option-a",
            name: "Option A",
            summary: "",
            icon: "doc.fill",
            tint: .accentColor,
            domain: .otherCaches,
            safety: .safe,
            items: [makeItem(name: "a", bytes: 1)]
        )
        let secondCategory = QuickCleanCategory(
            id: "option-b",
            name: "Option B",
            summary: "",
            icon: "doc.fill",
            tint: .accentColor,
            domain: .otherCaches,
            safety: .safe,
            items: [makeItem(name: "b", bytes: 1)]
        )
        let scan = QuickCleanScan(categories: [firstCategory, secondCategory])
        XCTAssertEqual(scan.populatedCategories.count, 2)
        XCTAssertEqual(scan.populatedCategories.map(\.id), ["option-a", "option-b"])
    }

    // MARK: - QuickCleanCleanedCategory

    /// `cleanedCategories(in:)` must report the *reclaimed* bytes — not the
    /// scanned bytes — so a partially-failed cleanup (e.g. one of three
    /// browser cache roots throws on trash) shows the real outcome.
    func testCleanedCategoriesReportsReclaimedBytesNotScannedBytes() {
        let category = makeCategory(id: "browser-cache", bytes: [100, 200, 300])
        let scan = QuickCleanScan(categories: [category])
        let deletedURL = category.items[1].url
        let result = CleanupResult(
            deletedURLs: [deletedURL],
            deletedItems: [DeletedItem(originalURL: deletedURL, bytesReclaimed: 250)],
            failedURLs: [],
            totalBytesReclaimed: 250
        )

        let cleaned = scan.cleanedCategories(in: result)

        XCTAssertEqual(cleaned.count, 1)
        XCTAssertEqual(cleaned.first?.reclaimedBytes, 250, "must reflect actual reclaimed bytes, not scanned (500)")
        XCTAssertEqual(cleaned.first?.reclaimedItems.count, 1)
        XCTAssertEqual(cleaned.first?.reclaimedItems.first?.url, deletedURL)
    }

    /// Categories with zero successful deletes must drop out of the breakdown.
    /// The original implementation kept the category and reported scanned
    /// bytes even when the Trash move failed for every item in it.
    func testCleanedCategoriesDropsCategoriesWithOnlyFailures() {
        let category = makeCategory(id: "browser-cache", bytes: [100])
        let scan = QuickCleanScan(categories: [category])
        let failedURL = category.items[0].url
        let result = CleanupResult(
            deletedURLs: [],
            deletedItems: [],
            failedURLs: [(failedURL, NSError(domain: "test", code: 1))],
            totalBytesReclaimed: 0
        )

        XCTAssertTrue(scan.cleanedCategories(in: result).isEmpty)
    }

    /// A category is included only if at least one of its items was
    /// successfully cleaned; failed items inside an otherwise-successful
    /// category are filtered out so the breakdown matches the real outcome.
    func testCleanedCategoriesExcludesFailedItemsButKeepsSuccessfulOnes() {
        let category = makeCategory(id: "browser-cache", bytes: [100, 200, 300])
        let scan = QuickCleanScan(categories: [category])
        let succeededURL = category.items[0].url
        let failedURL = category.items[2].url
        let result = CleanupResult(
            deletedURLs: [succeededURL],
            deletedItems: [DeletedItem(originalURL: succeededURL, bytesReclaimed: 100)],
            failedURLs: [(failedURL, NSError(domain: "test", code: 1))],
            totalBytesReclaimed: 100
        )

        let cleaned = scan.cleanedCategories(in: result)
        XCTAssertEqual(cleaned.count, 1)
        XCTAssertEqual(cleaned.first?.reclaimedBytes, 100)
        XCTAssertEqual(cleaned.first?.reclaimedItems.map(\.url), [succeededURL])
    }
}
