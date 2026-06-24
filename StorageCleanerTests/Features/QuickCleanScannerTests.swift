import Foundation
import XCTest
@testable import StorageCleaner

final class QuickCleanScannerTests: XCTestCase {
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

    private func makeOption(
        id: String,
        name: String = "Test",
        path: String,
        safety: CleanupSafety = .safe,
        domain: StorageDomain = .otherCaches
    ) -> CleanupOption {
        CleanupOption(
            id: id,
            name: name,
            description: "test",
            icon: "doc.fill",
            iconColor: "blue",
            domain: domain,
            safety: safety,
            paths: [path],
            isSafeByDefault: true,
            category: .system
        )
    }

    /// Each path in `CleanupOption.paths` maps to a single Quick Clean item:
    /// either a file or a directory. The scanner does not recurse, it just
    /// confirms the path exists and measures its on-disk size.
    func testScanCollectsExistingPathsAsOneItemEach() async throws {
        let firstPath = temporaryDirectory.appending(path: "first", directoryHint: .isDirectory).path
        let secondPath = temporaryDirectory.appending(path: "second", directoryHint: .isDirectory).path
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: firstPath),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: secondPath),
            withIntermediateDirectories: true
        )

        let options = [
            makeOption(id: "first", name: "First", path: firstPath),
            makeOption(id: "second", name: "Second", path: secondPath)
        ]

        let scanner = QuickCleanScanner(
            options: options,
            enabledIDs: ["first", "second"]
        )
        let scan = await scanner.scan()

        XCTAssertEqual(scan.populatedCategories.count, 2)
        XCTAssertEqual(scan.totalItemCount, 2)
    }

    func testScanSkipsOptionsWhosePathsDoNotExist() async throws {
        let missing = "/tmp/this-path-definitely-does-not-exist-\(UUID().uuidString)"
        let options = [makeOption(id: "missing", path: missing)]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["missing"])
        let scan = await scanner.scan()
        XCTAssertTrue(scan.populatedCategories.isEmpty)
        XCTAssertEqual(scan.totalBytes, 0)
    }

    func testScanReportsProgressForEachCategory() async throws {
        let pathA = temporaryDirectory.appending(path: "a", directoryHint: .isDirectory).path
        let pathB = temporaryDirectory.appending(path: "b", directoryHint: .isDirectory).path
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: pathA), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: pathB), withIntermediateDirectories: true)

        let options = [
            makeOption(id: "a", name: "A", path: pathA),
            makeOption(id: "b", name: "B", path: pathB)
        ]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["a", "b"])

        let collector = ProgressCollector()
        let scan = await scanner.scan { completed, total in
            await collector.append((completed, total))
        }

        XCTAssertEqual(scan.populatedCategories.count, 2)
        let count = await collector.count()
        let last = await collector.last()
        XCTAssertEqual(count, 2)
        XCTAssertEqual(last?.0, 2)
        XCTAssertEqual(last?.1, 2)
    }

    func testScanRespectsTildeExpansion() async throws {
        let relativePath = ".quickclean-test-\(UUID().uuidString)"
        XCTAssertEqual(
            UserHomeDirectory.expandingTilde(in: "~/\(relativePath)"),
            UserHomeDirectory.url.appending(path: relativePath, directoryHint: .isDirectory).path
        )
    }

    func testScannerSortsItemsBySizeDescending() async throws {
        let dir = temporaryDirectory.appending(path: "sort", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 1_000).write(to: dir.appending(path: "small.bin"))
        try Data(count: 50_000).write(to: dir.appending(path: "big.bin"))

        // Use a single option with two file paths so the items within the
        // single populated category are sorted by size.
        let options = [CleanupOption(
            id: "sort",
            name: "Sort",
            description: "test",
            icon: "doc.fill",
            iconColor: "blue",
            domain: .otherCaches,
            safety: .safe,
            paths: [dir.appending(path: "small.bin").path, dir.appending(path: "big.bin").path],
            isSafeByDefault: true,
            category: .system
        )]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["sort"])
        let scan = await scanner.scan()
        let category = try XCTUnwrap(scan.populatedCategories.first)
        XCTAssertEqual(category.items.count, 2)
        XCTAssertGreaterThan(category.items[0].bytes, category.items[1].bytes)
    }
}

private actor ProgressCollector {
    private(set) var snapshots: [(Int, Int)] = []

    func append(_ snapshot: (Int, Int)) {
        snapshots.append(snapshot)
    }

    func last() -> (Int, Int)? { snapshots.last }
    func count() -> Int { snapshots.count }
}
