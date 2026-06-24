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
        XCTAssertEqual(
            result.finding?.pathBytes[cacheDirectory],
            20_480,
            "pathBytes must carry per-path scan sizes so detail views don't recompute"
        )
        XCTAssertEqual(
            result.finding?.pathBytes.values.reduce(0, +),
            result.finding?.bytes,
            "Sum of pathBytes must equal the aggregate bytes"
        )
    }

    func testPHPDependencyScannerFindsNestedComposerVendorFolders() async throws {
        let composerCache = temporaryDirectory.appending(path: "composer-cache", directoryHint: .isDirectory)
        let nestedBackend = temporaryDirectory.appending(
            path: "digital-profile/backend",
            directoryHint: .isDirectory
        )
        let cryptoTest = temporaryDirectory.appending(path: "crypto-test", directoryHint: .isDirectory)
        let unrelatedVendor = temporaryDirectory.appending(path: "go-service/vendor", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: composerCache, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedBackend, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cryptoTest, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedVendor, withIntermediateDirectories: true)

        let backendVendor = nestedBackend.appending(path: "vendor", directoryHint: .isDirectory)
        let cryptoVendor = cryptoTest.appending(path: "vendor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: backendVendor, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cryptoVendor, withIntermediateDirectories: true)

        try #"{"require":{"php":"^8.3"}}"#.write(
            to: nestedBackend.appending(path: "composer.json"),
            atomically: true,
            encoding: .utf8
        )
        try #"{"require":{"guzzlehttp/guzzle":"^7.0"}}"#.write(
            to: cryptoTest.appending(path: "composer.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 1, count: 12_000).write(to: composerCache.appending(path: "packages.zip"))
        try Data(repeating: 2, count: 16_000).write(to: backendVendor.appending(path: "autoload.php"))
        try Data(repeating: 3, count: 20_000).write(to: cryptoVendor.appending(path: "composer.lock"))
        try Data(repeating: 4, count: 24_000).write(to: unrelatedVendor.appending(path: "module.go"))

        let scanner = PHPDependencyScanner(
            cachePaths: [composerCache],
            projectRoots: [temporaryDirectory],
            maxProjectDependencyDepth: 4,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = Set(result.finding?.filePaths.map(\.standardizedFileURL) ?? [])

        XCTAssertEqual(result.finding?.kind, .phpDependencies)
        XCTAssertEqual(result.finding?.domain, .webDevelopment)
        XCTAssertEqual(result.finding?.safety, .review)
        XCTAssertEqual(paths, Set([
            composerCache.standardizedFileURL,
            backendVendor.standardizedFileURL,
            cryptoVendor.standardizedFileURL
        ]))
        XCTAssertEqual(result.finding?.itemCount, 3)
        XCTAssertFalse(paths.contains(unrelatedVendor.standardizedFileURL))
    }

    func testPHPDependencyScannerTreatsVendorAutoloadAsComposerFallback() async throws {
        let project = temporaryDirectory.appending(path: "legacy-php", directoryHint: .isDirectory)
        let vendor = project.appending(path: "vendor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vendor, withIntermediateDirectories: true)
        try Data(repeating: 5, count: 12_000).write(to: vendor.appending(path: "autoload.php"))

        let scanner = PHPDependencyScanner(
            cachePaths: [],
            projectRoots: [temporaryDirectory],
            maxProjectDependencyDepth: 3,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.filePaths.map(\.standardizedFileURL), [vendor.standardizedFileURL])
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
        let iosPackage = downloads.appending(path: "InternalBuild.ipa")
        let androidPackage = downloads.appending(path: "debug.apk")
        let androidBundle = downloads.appending(path: "release.aab")
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
            iosPackage,
            androidPackage,
            androidBundle,
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
        XCTAssertEqual(result.inspectedItemCount, 16)
        XCTAssertEqual(result.finding?.pathBytes.values.reduce(0, +) ?? 0, result.finding?.bytes ?? 0)
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

    func testLargeFileScannerDefaultFloorSurfacesDocumentsOverTenMegabytes() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let largeDocuments = [
            downloads.appending(path: "report.pdf"),
            downloads.appending(path: "export.csv"),
            downloads.appending(path: "proposal.docx")
        ]
        let smallDocument = downloads.appending(path: "notes.pdf")

        for url in largeDocuments {
            try Data(repeating: 7, count: 10_500_000).write(to: url)
        }
        try Data(repeating: 7, count: 2_000_000).write(to: smallDocument)

        // No explicit minimumBytes -> uses the 10 MB collection floor.
        let scanner = LargeFileScanner(roots: [downloads], collector: FileSystemCollector())

        let result = await scanner.scan()
        let paths = result.finding?.filePaths.map(\.standardizedFileURL) ?? []

        XCTAssertEqual(result.finding?.kind, .largeFiles)
        XCTAssertEqual(Set(paths), Set(largeDocuments.map(\.standardizedFileURL)))
        XCTAssertFalse(paths.contains(smallDocument.standardizedFileURL))
    }

    func testCollectFilesPrioritizingLargestRetainsBiggestWhenCapped() throws {
        let root = temporaryDirectory.appending(path: "Bulk", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        // Distinct, block-aligned sizes so allocated-size ordering is unambiguous.
        let bySize = try (1...5).reduce(into: [Int: URL]()) { result, multiple in
            let url = root.appending(path: "file-\(multiple).bin")
            try Data(repeating: UInt8(multiple), count: multiple * 40_000).write(to: url)
            result[multiple] = url
        }

        let collected = FileSystemCollector().collectFiles(
            at: [root],
            matching: { _ in true },
            limit: 2,
            prioritizeLargest: true
        )
        let urls = Set(collected.candidates.map(\.url.standardizedFileURL))

        XCTAssertEqual(collected.candidates.count, 2)
        // The two largest (4x and 5x) must survive regardless of enumeration order.
        XCTAssertEqual(urls, Set([bySize[4], bySize[5]].compactMap { $0?.standardizedFileURL }))
        XCTAssertEqual(collected.inspectedItemCount, 5)
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

        XCTAssertEqual(statuses.map(\.scope), [.home])
        XCTAssertEqual(statuses.first?.url, UserHomeDirectory.url)
    }

    func testPermissionServiceValidatesActualHomeFolder() {
        let home = URL(filePath: "/Users/test", directoryHint: .isDirectory)
        let downloads = home.appending(path: "Downloads", directoryHint: .isDirectory)

        XCTAssertTrue(FileSystemPermissionService.isHomeFolder(home, homeDirectory: home))
        XCTAssertFalse(FileSystemPermissionService.isHomeFolder(downloads, homeDirectory: home))
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
