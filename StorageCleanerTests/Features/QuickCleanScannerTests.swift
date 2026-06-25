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
        domain: StorageDomain = .otherCaches,
        storageKind: StorageFindingKind = .junkFiles
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
            category: .system,
            storageKind: storageKind
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
            category: .system,
            storageKind: .junkFiles
        )]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["sort"])
        let scan = await scanner.scan()
        let category = try XCTUnwrap(scan.populatedCategories.first)
        XCTAssertEqual(category.items.count, 2)
        XCTAssertGreaterThan(category.items[0].bytes, category.items[1].bytes)
    }

    // MARK: - Sandbox / permission handling

    /// The original bug: a sandboxed build without a home-folder grant
    /// returned a list of 0 KB items because `FileManager.enumerator`
    /// silently returns nothing against protected paths. The scanner must
    /// detect the missing grant and surface it via `accessDenied` so the
    /// view can prompt for permission instead of misleadingly claiming
    /// there is "nothing to clean".
    func testScanMarksAccessDeniedWhenHomeFolderScopeIsMissing() async throws {
        let path = temporaryDirectory.appending(path: "x", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)

        let options = [makeOption(id: "x", path: path.path)]
        let scanner = QuickCleanScanner(
            options: options,
            enabledIDs: ["x"],
            permissionHandler: DenyingPermissionHandler()
        )
        let scan = await scanner.scan()

        XCTAssertTrue(scan.accessDenied)
        XCTAssertTrue(scan.populatedCategories.isEmpty)
    }

    /// When the user has granted access, the same option must report its
    /// real on-disk size. This is the regression test for the 0 KB bug —
    /// without the security scope, `collectExistingItems` would have
    /// returned a candidate with `bytes == 0` for every protected path.
    func testScanReportsRealSizesWhenHomeFolderScopeIsGranted() async throws {
        let path = temporaryDirectory.appending(path: "x", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        try Data(count: 50_000).write(to: path.appending(path: "data.bin"))

        let options = [makeOption(id: "x", path: path.path)]
        let scanner = QuickCleanScanner(
            options: options,
            enabledIDs: ["x"],
            permissionHandler: GrantingPermissionHandler()
        )
        let scan = await scanner.scan()

        XCTAssertFalse(scan.accessDenied)
        XCTAssertEqual(scan.populatedCategories.count, 1)
        let item = try XCTUnwrap(scan.populatedCategories.first?.items.first)
        XCTAssertGreaterThan(item.bytes, 0)
    }

    /// Tests that omit a permission handler must keep working unchanged so
    /// they can drive the scanner against synthetic paths without a
    /// permission layer.
    func testScanWorksWithoutPermissionHandler() async throws {
        let path = temporaryDirectory.appending(path: "x", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        try Data(count: 1_000).write(to: path.appending(path: "data.bin"))

        let options = [makeOption(id: "x", path: path.path)]
        let scanner = QuickCleanScanner(options: options, enabledIDs: ["x"])
        let scan = await scanner.scan()

        XCTAssertFalse(scan.accessDenied)
        XCTAssertEqual(scan.populatedCategories.count, 1)
    }
}

// MARK: - Permission handlers for sandbox-aware scanner tests

private final class DenyingPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] { [] }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? { nil }
}

private final class GrantingPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    private let lock = NSLock()
    private var didStop = false
    var stopped: Bool { lock.withLock { didStop } }

    func currentStatuses() -> [StoragePermissionStatus] { [] }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        SecurityScopedResourceAccess(onStop: { [weak self] in
            self?.lock.withLock { self?.didStop = true }
        })
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
