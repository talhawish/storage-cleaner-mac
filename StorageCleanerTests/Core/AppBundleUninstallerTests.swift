import Foundation
import XCTest
@testable import StorageCleaner

final class AppBundleUninstallerTests: XCTestCase {
    func testOnlyDirectApplicationsChildrenAreSupported() {
        XCTAssertTrue(
            AppBundleUninstaller.supportsAppTrashRemoval(
                for: URL(fileURLWithPath: "/Applications/Cleaner.app")
            )
        )
        XCTAssertFalse(
            AppBundleUninstaller.supportsAppTrashRemoval(
                for: URL(fileURLWithPath: "/Applications/Parent.app/Contents/Resources/Child.app")
            )
        )
        XCTAssertFalse(
            AppBundleUninstaller.supportsAppTrashRemoval(
                for: URL(fileURLWithPath: "/Applications-Backup/Cleaner.app")
            )
        )
    }

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
        XCTAssertTrue(recorder.workspaceTrashRequests.isEmpty)
    }

    func testPermissionDeniedAfterApplicationsAccessFallsBackToWorkspaceRecycle() async throws {
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
        XCTAssertEqual(recorder.workspaceTrashRequests, [app.standardizedFileURL])
    }

    func testWorkspaceAuthorizationRequirementIsPreserved() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let permissionError = CocoaError(.fileWriteNoPermission)
        let authorizationError = AppBundleUninstallerError.authorizationRequired(app.standardizedFileURL)
        let recorder = AppBundleUninstallerRecorder(
            trashError: permissionError,
            userAccessTrashError: permissionError,
            workspaceTrashError: authorizationError
        )
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected workspace recycle authorization requirement to be preserved.")
        } catch let error as AppBundleUninstallerError {
            guard case let .authorizationRequired(url) = error else {
                return XCTFail("Expected authorizationRequired error, got \(error).")
            }
            XCTAssertEqual(url, app.standardizedFileURL)
        }
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
            moveToTrashWithWorkspace: { url in try recorder.moveToTrashWithWorkspace(url) }
        )
    }
}

private final class AppBundleUninstallerRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let trashError: Error?
    private let userAccessTrashError: Error?
    private let workspaceTrashError: Error?
    private var _trashRequests: [URL] = []
    private var _userAccessTrashRequests: [URL] = []
    private var _workspaceTrashRequests: [URL] = []

    init(
        trashError: Error? = nil,
        userAccessTrashError: Error? = nil,
        workspaceTrashError: Error? = nil
    ) {
        self.trashError = trashError
        self.userAccessTrashError = userAccessTrashError
        self.workspaceTrashError = workspaceTrashError
    }

    var trashRequests: [URL] {
        lock.withLock { _trashRequests }
    }

    var userAccessTrashRequests: [URL] {
        lock.withLock { _userAccessTrashRequests }
    }

    var workspaceTrashRequests: [URL] {
        lock.withLock { _workspaceTrashRequests }
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

    func moveToTrashWithWorkspace(_ url: URL) throws {
        try lock.withLock {
            _workspaceTrashRequests.append(url)
            if let workspaceTrashError { throw workspaceTrashError }
        }
    }
}
