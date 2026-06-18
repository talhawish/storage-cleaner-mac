import Foundation
import XCTest
@testable import StorageCleaner

final class FileSystemScannerTests: XCTestCase {
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

    func testPathListScannerMeasuresExistingFolders() async throws {
        let cacheDirectory = temporaryDirectory.appending(path: "DerivedData", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 20_000).write(to: cacheDirectory.appending(path: "cache.bin"))

        let scanner = PathListScanner(
            kind: .xcodeArtifacts,
            domain: .appleDevelopment,
            paths: [cacheDirectory],
            safety: .safe,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .xcodeArtifacts)
        XCTAssertEqual(result.finding?.bytes, 20_480)
        XCTAssertEqual(result.inspectedItemCount, 1)
    }

    func testDuplicateMediaScannerReportsLikelyDuplicatesOnly() async throws {
        let pictures = temporaryDirectory.appending(path: "Pictures", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        let payload = Data(repeating: 2, count: 20_000)

        try payload.write(to: pictures.appending(path: "launch.png"))
        try payload.write(to: pictures.appending(path: "launch copy.png"))
        try Data(repeating: 3, count: 20_000).write(to: pictures.appending(path: "unique.png"))

        let scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: [pictures],
            extensions: ["png"],
            minimumBytes: 128,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .duplicatePhotos)
        XCTAssertEqual(result.finding?.itemCount, 1)
        XCTAssertEqual(result.finding?.bytes, 20_480)
    }

    func testPermissionServiceReportsKnownScopes() {
        let service = FileSystemPermissionService()

        let statuses = service.currentStatuses()

        XCTAssertEqual(statuses.map(\.scope), StoragePermissionScope.allCases)
        XCTAssertFalse(statuses.isEmpty)
    }

    func testCLIAppScannerDetectsRustupViaHomePath() async throws {
        let rustup = temporaryDirectory.appending(path: ".rustup", directoryHint: .isDirectory)
        let toolchainSubpath = "toolchains/nightly-x86_64-apple-darwin/lib/rustlib"
        let toolchainDir = rustup.appending(path: toolchainSubpath, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: toolchainDir, withIntermediateDirectories: true)
        try Data(repeating: 5, count: 10_000).write(to: toolchainDir.appending(path: "rustc"))

        let scanner = CLIAppScanner(
            paths: PathBuilder(homeDirectory: temporaryDirectory),
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .cliApps)
        XCTAssertEqual(result.finding?.domain, .cliTooling)
        XCTAssertEqual(result.finding?.safety, .review)
        XCTAssertGreaterThan(result.finding?.bytes ?? 0, 0)
        XCTAssertGreaterThanOrEqual(result.inspectedItemCount, 1)
    }

    func testCLIAppScannerDetectsHomebrewCacheViaHomePath() async throws {
        let cache = temporaryDirectory.appending(path: "Library/Caches/Homebrew", directoryHint: .isDirectory)
        let downloadsDir = cache.appending(path: "downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let bottle = "6dbe8b3f4a--ffmpeg--4.4.1.bottle.tar.gz"
        try Data(repeating: 6, count: 50_000).write(to: downloadsDir.appending(path: bottle))

        let scanner = CLIAppScanner(
            paths: PathBuilder(homeDirectory: temporaryDirectory),
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .cliApps)
        XCTAssertEqual(result.finding?.domain, .cliTooling)
        XCTAssertGreaterThanOrEqual(result.inspectedItemCount, 1)
    }

    func testCLIAppScannerScansSystemPathsWhenHomeIsEmpty() async throws {
        let emptyDir = temporaryDirectory.appending(path: "empty", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let scanner = CLIAppScanner(
            paths: PathBuilder(homeDirectory: emptyDir),
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .cliApps)
        XCTAssertEqual(result.finding?.domain, .cliTooling)
    }
}
