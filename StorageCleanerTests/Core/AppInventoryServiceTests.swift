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
