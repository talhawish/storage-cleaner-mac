import Foundation
import XCTest
@testable import StorageCleaner

final class AppInventoryServiceTests: XCTestCase {
    func testUninstallMovesExactAppURLToTrash() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(existingPaths: [app.url.standardizedFileURL.path])
        let service = makeService(recorder: recorder)

        try await service.uninstallApp(app)

        XCTAssertEqual(recorder.recycledURLs, [[app.url.standardizedFileURL]])
        XCTAssertTrue(recorder.trashedURLs.isEmpty)
        XCTAssertFalse(recorder.exists(app.url.standardizedFileURL.path))
    }

    func testUninstallFallsBackToTrashWhenRecycleFails() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(
            existingPaths: [app.url.standardizedFileURL.path],
            recycleError: CocoaError(.fileWriteNoPermission)
        )
        let service = makeService(recorder: recorder)

        try await service.uninstallApp(app)

        XCTAssertEqual(recorder.recycledURLs, [[app.url.standardizedFileURL]])
        XCTAssertEqual(recorder.trashedURLs, [app.url.standardizedFileURL])
        XCTAssertFalse(recorder.exists(app.url.standardizedFileURL.path))
    }

    func testUninstallFailsWhenAppBundleStillExistsAfterTrashMove() async throws {
        let app = appItem(path: "/Applications/Cleaner.app")
        let recorder = AppUninstallRecorder(
            existingPaths: [app.url.standardizedFileURL.path],
            removeOnRecycle: false
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

    func testAppIdentityUsesExactPathInsteadOfBundleIdentifier() {
        let first = appItem(path: "/Applications/Cleaner.app", bundleIdentifier: "com.example.cleaner")
        let second = appItem(path: "/Users/me/Applications/Cleaner.app", bundleIdentifier: "com.example.cleaner")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.bundleIdentifier, second.bundleIdentifier)
    }

    private func makeService(recorder: AppUninstallRecorder) -> AppInventoryService {
        AppInventoryService(
            recycleItems: { urls in try recorder.recycle(urls) },
            trashItem: { url in try recorder.trash(url) },
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
    private let recycleError: Error?
    private let removeOnRecycle: Bool

    private var _recycledURLs: [[URL]] = []
    private var _trashedURLs: [URL] = []

    init(
        existingPaths: Set<String>,
        recycleError: Error? = nil,
        removeOnRecycle: Bool = true
    ) {
        self.existingPaths = existingPaths
        self.recycleError = recycleError
        self.removeOnRecycle = removeOnRecycle
    }

    var recycledURLs: [[URL]] {
        lock.withLock { _recycledURLs }
    }

    var trashedURLs: [URL] {
        lock.withLock { _trashedURLs }
    }

    func recycle(_ urls: [URL]) throws {
        try lock.withLock {
            _recycledURLs.append(urls)
            if let recycleError { throw recycleError }
            if removeOnRecycle {
                for url in urls {
                    existingPaths.remove(url.standardizedFileURL.path)
                }
            }
        }
    }

    func trash(_ url: URL) throws {
        lock.withLock {
            _trashedURLs.append(url)
            existingPaths.remove(url.standardizedFileURL.path)
        }
    }

    func exists(_ path: String) -> Bool {
        lock.withLock { existingPaths.contains(path) }
    }
}
