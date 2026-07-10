import Foundation
import XCTest
@testable import StorageCleaner

final class AppBundleUninstallerTests: XCTestCase {
    func testDirectMoveToTrashUsesExactAppBundle() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder()
        let uninstaller = makeUninstaller(recorder: recorder)

        try await uninstaller.uninstall(app)

        XCTAssertEqual(recorder.trashRequests, [app.standardizedFileURL])
        XCTAssertTrue(recorder.userAccessTrashRequests.isEmpty)
    }

    func testPermissionDeniedFallsBackToUserSelectedApplicationsAccess() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let permissionError = CocoaError(.fileWriteNoPermission)
        let recorder = AppBundleUninstallerRecorder(trashError: permissionError)
        let uninstaller = makeUninstaller(recorder: recorder)

        try await uninstaller.uninstall(app)

        XCTAssertEqual(recorder.trashRequests, [app.standardizedFileURL])
        XCTAssertEqual(recorder.userAccessTrashRequests, [app.standardizedFileURL])
        XCTAssertTrue(recorder.adminTrashRequests.isEmpty)
    }

    func testPermissionDeniedAfterApplicationsAccessFallsBackToAdministratorAuthorization() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let permissionError = CocoaError(.fileWriteNoPermission)
        let recorder = AppBundleUninstallerRecorder(
            trashError: permissionError,
            userAccessTrashError: permissionError
        )
        let uninstaller = makeUninstaller(recorder: recorder)

        try await uninstaller.uninstall(app)

        XCTAssertEqual(recorder.trashRequests, [app.standardizedFileURL])
        XCTAssertEqual(recorder.userAccessTrashRequests, [app.standardizedFileURL])
        XCTAssertEqual(recorder.adminTrashRequests, [app.standardizedFileURL])
    }

    func testUnsupportedLocationIsRejectedBeforeRemoval() async throws {
        let app = URL(fileURLWithPath: "/tmp/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder()
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected unsupported app location to be rejected.")
        } catch let error as AppBundleUninstallerError {
            guard case let .unsupportedLocation(url) = error else {
                return XCTFail("Expected unsupportedLocation error, got \(error).")
            }
            XCTAssertEqual(url, app.standardizedFileURL)
        }

        XCTAssertTrue(recorder.trashRequests.isEmpty)
        XCTAssertTrue(recorder.userAccessTrashRequests.isEmpty)
    }

    func testNonPermissionFailureIsPreserved() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder(trashError: CocoaError(.fileNoSuchFile))
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected Trash move failure to be preserved.")
        } catch {
            XCTAssertEqual((error as NSError).code, CocoaError.fileNoSuchFile.rawValue)
        }

        XCTAssertEqual(recorder.trashRequests, [app.standardizedFileURL])
        XCTAssertTrue(recorder.userAccessTrashRequests.isEmpty)
    }

    func testUserSelectedAccessFailureIsReported() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let accessError = AppBundleUninstallerError.applicationsAccessNotGranted(app.standardizedFileURL)
        let recorder = AppBundleUninstallerRecorder(
            trashError: CocoaError(.fileWriteNoPermission),
            userAccessTrashError: accessError
        )
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected user-selected access failure to be reported.")
        } catch let error as AppBundleUninstallerError {
            guard case let .applicationsAccessNotGranted(url) = error else {
                return XCTFail("Expected applicationsAccessNotGranted error, got \(error).")
            }
            XCTAssertEqual(url, app.standardizedFileURL)
        }

        XCTAssertEqual(recorder.userAccessTrashRequests, [app.standardizedFileURL])
    }

    private func makeUninstaller(recorder: AppBundleUninstallerRecorder) -> AppBundleUninstaller {
        AppBundleUninstaller(
            moveToTrashDirectly: { url in try recorder.moveToTrash(url) },
            moveToTrashWithUserSelectedAccess: { url in try recorder.moveToTrashWithUserAccess(url) },
            moveToTrashWithAdminAuthorization: { url in try recorder.moveToTrashWithAdmin(url) }
        )
    }
}

private final class AppBundleUninstallerRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let trashError: Error?
    private let userAccessTrashError: Error?
    private let adminTrashError: Error?
    private var _trashRequests: [URL] = []
    private var _userAccessTrashRequests: [URL] = []
    private var _adminTrashRequests: [URL] = []

    init(
        trashError: Error? = nil,
        userAccessTrashError: Error? = nil,
        adminTrashError: Error? = nil
    ) {
        self.trashError = trashError
        self.userAccessTrashError = userAccessTrashError
        self.adminTrashError = adminTrashError
    }

    var trashRequests: [URL] {
        lock.withLock { _trashRequests }
    }

    var userAccessTrashRequests: [URL] {
        lock.withLock { _userAccessTrashRequests }
    }

    var adminTrashRequests: [URL] {
        lock.withLock { _adminTrashRequests }
    }

    func moveToTrash(_ url: URL) throws {
        try lock.withLock {
            _trashRequests.append(url)
            if let trashError { throw trashError }
        }
    }

    func moveToTrashWithUserAccess(_ url: URL) throws {
        try lock.withLock {
            _userAccessTrashRequests.append(url)
            if let userAccessTrashError { throw userAccessTrashError }
        }
    }

    func moveToTrashWithAdmin(_ url: URL) throws {
        try lock.withLock {
            _adminTrashRequests.append(url)
            if let adminTrashError { throw adminTrashError }
        }
    }
}
