import Foundation
import XCTest
@testable import StorageCleaner

final class QuickCleanViewModelTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    private func makeOption(id: String, path: String) -> CleanupOption {
        CleanupOption(
            id: id,
            name: id,
            description: "test",
            icon: "doc.fill",
            iconColor: "blue",
            domain: .otherCaches,
            safety: .safe,
            paths: [path],
            isSafeByDefault: true,
            category: .system,
            storageKind: .junkFiles
        )
    }

    @MainActor
    func testStartScanTransitionsToReviewWhenItemsFound() async throws {
        let dir = temporaryDirectory.appending(path: "x", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 50_000).write(to: dir.appending(path: "a.bin"))

        let scanner = QuickCleanScanner(
            options: [makeOption(id: "x", path: dir.path)],
            enabledIDs: ["x"]
        )
        let viewModel = QuickCleanViewModel(onClean: { _ in
            CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        })
        let scan = await scanner.scan()
        viewModel.setScanResultForTesting(scan)

        XCTAssertEqual(viewModel.phase, .review)
        XCTAssertTrue(viewModel.hasSelection)
        XCTAssertEqual(viewModel.totalSelectedItems, 1)
    }

    @MainActor
    func testStartScanTransitionsToSuccessWhenNoItems() async throws {
        let scanner = QuickCleanScanner(
            options: [makeOption(id: "missing", path: "/tmp/\(UUID().uuidString)")],
            enabledIDs: ["missing"]
        )
        let scan = await scanner.scan()
        let viewModel = QuickCleanViewModel(onClean: { _ in
            CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        })
        viewModel.setScanResultForTesting(scan)
        XCTAssertEqual(viewModel.phase, .success)
        XCTAssertFalse(viewModel.hasSelection)
    }

    @MainActor
    func testSelectAllAndDeselectAll() async throws {
        let pathA = temporaryDirectory.appending(path: "a", directoryHint: .isDirectory).path
        let pathB = temporaryDirectory.appending(path: "b", directoryHint: .isDirectory).path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: pathA), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: pathB), withIntermediateDirectories: true)

        let options = [
            makeOption(id: "a", path: pathA),
            makeOption(id: "b", path: pathB)
        ]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["a", "b"])
        let scan = await scanner.scan()
        let viewModel = QuickCleanViewModel(onClean: { _ in
            CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        })
        viewModel.setScanResultForTesting(scan)

        XCTAssertEqual(viewModel.totalSelectedItems, 2)
        viewModel.deselectAll()
        XCTAssertEqual(viewModel.totalSelectedItems, 0)
        viewModel.selectAll()
        XCTAssertEqual(viewModel.totalSelectedItems, 2)
    }

    @MainActor
    func testToggleCategorySelectsAndDeselects() async throws {
        let path = temporaryDirectory.appending(path: "toggle", directoryHint: .isDirectory).path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)

        let scanner = QuickCleanScanner(
            options: [makeOption(id: "toggle", path: path)],
            enabledIDs: ["toggle"]
        )
        let scan = await scanner.scan()
        let viewModel = QuickCleanViewModel(onClean: { _ in
            CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        })
        viewModel.setScanResultForTesting(scan)
        let category = try XCTUnwrap(viewModel.populatedCategories.first)

        XCTAssertTrue(viewModel.isCategoryFullySelected(category))
        viewModel.toggleCategory(category)
        XCTAssertFalse(viewModel.isCategoryFullySelected(category))
        XCTAssertEqual(viewModel.totalSelectedItems, 0)
        viewModel.toggleCategory(category)
        XCTAssertTrue(viewModel.isCategoryFullySelected(category))
    }

    /// When the scanner reports an access-denied result (sandboxed build,
    /// no home folder grant), the view model must transition to a
    /// dedicated `.needsAccess` phase so the view can prompt for
    /// permission instead of misleadingly showing an empty review list.
    @MainActor
    func testAccessDeniedScanTransitionsToNeedsAccessPhase() {
        let viewModel = QuickCleanViewModel(onClean: { _ in
            CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        })
        viewModel.setScanResultForTesting(
            QuickCleanScan(categories: [], accessDenied: true)
        )
        XCTAssertEqual(viewModel.phase, .needsAccess)
        XCTAssertFalse(viewModel.hasSelection)
    }
}
