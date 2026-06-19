import Foundation
import XCTest
@testable import StorageCleaner

final class FileSystemScannerTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var trashedURLs: [URL] = []

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        for url in trashedURLs {
            try? FileManager.default.removeItem(at: url)
        }
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

    func testScreenRecordingScannerReturnsVideosNotScreenshots() async throws {
        let movies = temporaryDirectory.appending(path: "Movies", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: movies, withIntermediateDirectories: true)
        let recording = movies.appending(path: "Screen Recording 2026-06-19 at 10.00.00.mov")
        let screenshot = movies.appending(path: "Screen Recording screenshot.png")

        try Data(repeating: 7, count: 30_000).write(to: recording)
        try Data(repeating: 8, count: 30_000).write(to: screenshot)

        let scanner = ScreenRecordingScanner(
            roots: [movies],
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .screenRecordings)
        XCTAssertEqual(
            result.finding?.filePaths.map { $0.standardizedFileURL },
            [recording.standardizedFileURL]
        )
        XCTAssertEqual(result.inspectedItemCount, 2)
    }

    func testScreenshotScannerDetectsMacAndSimulatorScreenshots() async throws {
        let desktop = temporaryDirectory.appending(path: "Desktop", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        let macScreenshot = desktop.appending(path: "Screenshot 2026-06-19 at 1.53.49 AM.png")
        let simulatorScreenshot = desktop.appending(
            path: "Simulator Screenshot - iPhone 17 Pro - 2026-05-22 at 19.44.22.webp"
        )
        let unrelatedImage = desktop.appending(path: "passport-scan.png")

        try Data(repeating: 1, count: 12_000).write(to: macScreenshot)
        try Data(repeating: 2, count: 12_000).write(to: simulatorScreenshot)
        try Data(repeating: 3, count: 12_000).write(to: unrelatedImage)

        let scanner = ScreenshotStorageScanner(
            roots: [desktop],
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = result.finding?.filePaths.map { $0.standardizedFileURL } ?? []

        XCTAssertEqual(result.finding?.kind, .screenshots)
        XCTAssertEqual(Set(paths), Set([
            macScreenshot.standardizedFileURL,
            simulatorScreenshot.standardizedFileURL
        ]))
        XCTAssertEqual(result.inspectedItemCount, 3)
    }

    func testLargeFileScannerDetectsNonMediaFilesOverThreshold() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let diskImage = downloads.appending(path: "Xcode-installer.dmg")
        let archive = downloads.appending(path: "dataset.zip")
        let zstdArchive = downloads.appending(path: "logs.tar.zst")
        let debianPackage = downloads.appending(path: "postgresql-client.deb")
        let javaArchive = downloads.appending(path: "service.jar")
        let xipArchive = downloads.appending(path: "Xcode.xip")
        let geoDatabase = downloads.appending(path: "GeoLite2-City.mmdb")
        let databaseDump = downloads.appending(path: "production.sql")
        let document = downloads.appending(path: "research-paper.pdf")
        let audio = downloads.appending(path: "mixdown.mp3")
        let textExport = downloads.appending(path: "error-report.txt")
        let extensionlessData = downloads.appending(path: "large-export")
        let smallFile = downloads.appending(path: "notes.txt")
        let expectedLargeFiles = [
            diskImage,
            archive,
            zstdArchive,
            debianPackage,
            javaArchive,
            xipArchive,
            geoDatabase,
            databaseDump,
            document,
            audio,
            textExport,
            extensionlessData
        ]

        for (index, url) in expectedLargeFiles.enumerated() {
            try Data(repeating: UInt8(index + 1), count: 13_000 + index).write(to: url)
        }
        try Data(repeating: 9, count: 4_000).write(to: smallFile)

        let scanner = LargeFileScanner(
            roots: [downloads],
            minimumBytes: 10_000,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = result.finding?.filePaths.map { $0.standardizedFileURL } ?? []

        XCTAssertEqual(result.finding?.kind, .largeFiles)
        XCTAssertEqual(Set(paths), Set(expectedLargeFiles.map(\.standardizedFileURL)))
        XCTAssertEqual(result.inspectedItemCount, 13)
    }

    func testLargeFileScannerExcludesAppAndDependencyInternals() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        let appSupport = temporaryDirectory.appending(
            path: "Library/Application Support/UsefulApp",
            directoryHint: .isDirectory
        )
        let nodeModules = downloads.appending(path: "project/node_modules/package", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)

        let installer = downloads.appending(path: "installer.dmg")
        let appDatabase = appSupport.appending(path: "app-store.sqlite")
        let dependencyArchive = nodeModules.appending(path: "bundle.zip")
        let hiddenArchive = downloads.appending(path: ".private-backup.zip")
        let executableArchive = downloads.appending(path: "installer-helper.zip")

        try Data(repeating: 1, count: 24_000).write(to: installer)
        try Data(repeating: 2, count: 24_000).write(to: appDatabase)
        try Data(repeating: 3, count: 24_000).write(to: dependencyArchive)
        try Data(repeating: 4, count: 24_000).write(to: hiddenArchive)
        try Data(repeating: 5, count: 24_000).write(to: executableArchive)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableArchive.path
        )

        let scanner = LargeFileScanner(
            roots: [temporaryDirectory],
            minimumBytes: 10_000,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = result.finding?.filePaths.map { $0.standardizedFileURL } ?? []

        XCTAssertEqual(paths, [installer.standardizedFileURL])
    }

    func testCleanupServiceMovesItemsToTrash() async throws {
        let file = temporaryDirectory.appending(path: "delete-me.txt")
        try Data(repeating: 9, count: 4_096).write(to: file)

        let result = await FileManagerCleanupService().delete(urls: [file])
        trashedURLs.append(contentsOf: result.deletedURLs)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.deletedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(result.deletedURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertGreaterThan(result.totalBytesReclaimed, 0)
        XCTAssertEqual(result.deletedItems.count, 1)
        XCTAssertEqual(result.deletedItems.first?.originalURL, file)
        XCTAssertGreaterThan(result.deletedItems.first?.bytesReclaimed ?? 0, 0)
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
            homeDirectory: temporaryDirectory,
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
            homeDirectory: temporaryDirectory,
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
            homeDirectory: emptyDir,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .cliApps)
        XCTAssertEqual(result.finding?.domain, .cliTooling)
    }
}
