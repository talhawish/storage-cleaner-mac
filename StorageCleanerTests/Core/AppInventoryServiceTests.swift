import Foundation
import XCTest
@testable import StorageCleaner

final class AppInventoryServiceTests: XCTestCase {
    func testUninstallRemovesExactAppBundle() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(existingPaths: [app.url.standardizedFileURL.path])
        let service = makeService(recorder: recorder)

        try await service.uninstallApp(app)

        XCTAssertEqual(recorder.removedURLs, [app.url.standardizedFileURL])
        XCTAssertFalse(recorder.exists(app.url.standardizedFileURL.path))
    }

    func testUninstallReportsPermissionDenied() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(
            existingPaths: [app.url.standardizedFileURL.path],
            removeError: CocoaError(.fileWriteNoPermission)
        )
        let service = makeService(recorder: recorder)

        do {
            try await service.uninstallApp(app)
            XCTFail("Expected uninstall to fail when macOS denies write permission.")
        } catch let error as AppUninstallError {
            guard case let .permissionDenied(url) = error else {
                return XCTFail("Expected permissionDenied error, got \(error).")
            }
            XCTAssertEqual(url, app.url.standardizedFileURL)
        }
    }

    func testUninstallFailsWhenAppBundleStillExistsAfterRemoval() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(
            existingPaths: [app.url.standardizedFileURL.path],
            removeOnUninstall: false
        )
        let service = makeService(recorder: recorder)

        do {
            try await service.uninstallApp(app)
            XCTFail("Expected uninstall to fail when the original app bundle still exists.")
        } catch let error as AppUninstallError {
            guard case let .stillPresent(url) = error else {
                return XCTFail("Expected stillPresent error, got \(error).")
            }
            XCTAssertEqual(url, app.url.standardizedFileURL)
        }
    }

    func testAdministratorApprovalFailureKeepsUnderlyingMessage() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(
            existingPaths: [app.url.standardizedFileURL.path],
            removeError: AppBundleUninstallerError.administratorApprovalFailed(
                app.url.standardizedFileURL,
                "User canceled."
            )
        )
        let service = makeService(recorder: recorder)

        do {
            try await service.uninstallApp(app)
            XCTFail("Expected administrator approval failure to surface.")
        } catch let error as AppUninstallError {
            guard case let .failed(url, message) = error else {
                return XCTFail("Expected failed error, got \(error).")
            }
            XCTAssertEqual(url, app.url.standardizedFileURL)
            XCTAssertEqual(message, "User canceled.")
        }
    }

    func testAppIdentityUsesExactPathInsteadOfBundleIdentifier() {
        let first = appItem(path: "/Applications/Cleaner.app", bundleIdentifier: "com.example.cleaner")
        let second = appItem(path: "/Users/me/Applications/Cleaner.app", bundleIdentifier: "com.example.cleaner")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.bundleIdentifier, second.bundleIdentifier)
    }

    func testDirectorySizeCountsDotPrefixedHiddenFilesInAppBundle() throws {
        let fixture = try AppBundleFixture.create(includeAppleDouble: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }

        let visibleBytes = fixture.relativePaths
            .filter { URL(fileURLWithPath: $0).lastPathComponent.hasPrefix(".") == false }
            .map { StorageFormatting.fileSize(at: fixture.url.appendingPathComponent($0)) }
            .reduce(Int64(0), +)
        let hiddenBytes = fixture.relativePaths
            .filter { URL(fileURLWithPath: $0).lastPathComponent.hasPrefix(".") }
            .map { StorageFormatting.fileSize(at: fixture.url.appendingPathComponent($0)) }
            .reduce(Int64(0), +)

        let reported = AppInventoryService.directorySize(
            at: fixture.url,
            fileManager: .default
        )

        XCTAssertGreaterThan(hiddenBytes, 0, "Fixture must include hidden files so the test is meaningful.")
        XCTAssertEqual(
            reported,
            visibleBytes + hiddenBytes,
            "directorySize must include Contents/.DS_Store and other .-prefixed hidden files."
        )
    }

    func testDirectorySizeSkipsDirectoriesInAppBundle() throws {
        let fixture = try AppBundleFixture.create(includeAppleDouble: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }

        let reported = AppInventoryService.directorySize(
            at: fixture.url,
            fileManager: .default
        )

        let filesOnly = fixture.relativePaths
            .map { StorageFormatting.fileSize(at: fixture.url.appendingPathComponent($0)) }
            .reduce(Int64(0), +)

        XCTAssertEqual(
            reported,
            filesOnly,
            "Directory entries must be skipped — only regular files contribute to the size."
        )
    }

    func testDuBasedSizeIncludesAppleDoubleFiles() async throws {
        let fixture = try AppBundleFixture.create(includeAppleDouble: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }

        let visibleBytes = fixture.relativePaths
            .filter { URL(fileURLWithPath: $0).lastPathComponent.hasPrefix("._") == false }
            .map { StorageFormatting.fileSize(at: fixture.url.appendingPathComponent($0)) }
            .reduce(Int64(0), +)
        let appleDoubleBytes = fixture.relativePaths
            .filter { URL(fileURLWithPath: $0).lastPathComponent.hasPrefix("._") }
            .map { StorageFormatting.fileSize(at: fixture.url.appendingPathComponent($0)) }
            .reduce(Int64(0), +)

        let reported = await AppInventoryService.duBasedSize(at: fixture.url)

        XCTAssertNotNil(reported, "du -sk must be available on macOS test hosts.")
        XCTAssertGreaterThan(appleDoubleBytes, 0, "Fixture must include AppleDouble files so the test is meaningful.")
        XCTAssertGreaterThanOrEqual(
            reported ?? 0,
            visibleBytes + appleDoubleBytes,
            "du -sk must count AppleDouble ._* files that the FileManager walker hides."
        )
    }

    func testDuBasedSizeFallsBackToWalkerWhenProcessFails() async throws {
        let failingExecutor = FailingProcessExecutor()
        let fixture = try AppBundleFixture.create(includeAppleDouble: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }

        let size = await AppInventoryService.duBasedSize(at: fixture.url, executor: failingExecutor)

        XCTAssertNil(size, "duBasedSize must return nil so the caller can fall back when du fails.")
    }

    func testLiveSizePrefersDuOverWalker() async throws {
        let fixture = try AppBundleFixture.create(includeAppleDouble: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: fixture.root) }

        let walkerOnly = AppInventoryService.directorySize(at: fixture.url, fileManager: .default)
        let live = await AppInventoryService.liveSize(fixture.url)

        XCTAssertGreaterThan(
            live,
            walkerOnly,
            "liveSize must include AppleDouble ._* files via du -sk; the walker alone misses them."
        )
    }

    private func makeService(recorder: AppUninstallRecorder) -> AppInventoryService {
        AppInventoryService(
            uninstallAppBundle: { url in try recorder.remove(url) },
            fileExists: { path in recorder.exists(path) },
            verificationAttempts: 1,
            verificationDelay: .zero
        )
    }

    private func appItem(
        path: String,
        bundleIdentifier: String = "com.example.cleaner",
        isSystemApp: Bool = false
    ) -> AppItem {
        AppItem(
            name: URL(filePath: path).deletingPathExtension().lastPathComponent,
            bundleIdentifier: bundleIdentifier,
            url: URL(filePath: path),
            sizeBytes: 42_000,
            isSystemApp: isSystemApp
        )
    }
}

private final class AppUninstallRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var existingPaths: Set<String>
    private let removeError: Error?
    private let removeOnUninstall: Bool

    private var _removedURLs: [URL] = []

    init(
        existingPaths: Set<String>,
        removeError: Error? = nil,
        removeOnUninstall: Bool = true
    ) {
        self.existingPaths = existingPaths
        self.removeError = removeError
        self.removeOnUninstall = removeOnUninstall
    }

    var removedURLs: [URL] {
        lock.withLock { _removedURLs }
    }

    func remove(_ url: URL) throws {
        try lock.withLock {
            _removedURLs.append(url)
            if let removeError { throw removeError }
            if removeOnUninstall {
                existingPaths.remove(url.standardizedFileURL.path)
            }
        }
    }

    func exists(_ path: String) -> Bool {
        lock.withLock { existingPaths.contains(path) }
    }
}

private struct AppBundleFixture {
    let root: URL
    let url: URL
    let relativePaths: [String]

    static func create(
        in parent: URL = FileManager.default.temporaryDirectory,
        includeAppleDouble: Bool = false
    ) throws -> AppBundleFixture {
        let root = parent.appendingPathComponent(
            "AppInventoryServiceTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let bundle = root.appendingPathComponent("Fixture.app", isDirectory: true)
        let macos = bundle.appendingPathComponent("Contents/MacOS", isDirectory: true)
        let lproj = bundle.appendingPathComponent("Contents/Resources/en.lproj", isDirectory: true)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: lproj, withIntermediateDirectories: true)

        var entries: [(String, Data)] = [
            ("Contents/MacOS/binary", Data(repeating: 0xAB, count: 100_000)),
            ("Contents/Resources/en.lproj/Localizable.strings", Data(repeating: 0xCD, count: 50_000)),
            ("Contents/Resources/en.lproj/.localized", Data(repeating: 0x34, count: 8_000)),
            ("Contents/.DS_Store", Data(repeating: 0x12, count: 10_000))
        ]
        if includeAppleDouble {
            entries.append(
                ("Contents/Resources/en.lproj/._Localizable.strings", Data(repeating: 0xEF, count: 25_000))
            )
        }

        for (relativePath, contents) in entries {
            try contents.write(to: bundle.appendingPathComponent(relativePath))
        }

        return AppBundleFixture(
            root: root,
            url: bundle,
            relativePaths: entries.map(\.0)
        )
    }
}

private struct FailingProcessExecutor: ProcessExecuting {
    func run(executable: URL, arguments: [String]) async throws -> ProcessRunResult {
        throw ProcessRunError(
            executable: executable.path,
            arguments: arguments,
            exitCode: -1,
            standardError: Data("unavailable".utf8)
        )
    }
}
