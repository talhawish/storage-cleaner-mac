import Foundation
import XCTest
@testable import StorageCleaner

final class AppBundleUninstallerTests: XCTestCase {
    func testDirectRemovalDoesNotRequestAdministratorApproval() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder()
        let uninstaller = makeUninstaller(recorder: recorder)

        try await uninstaller.uninstall(app)

        XCTAssertEqual(recorder.directRemovals, [app.standardizedFileURL])
        XCTAssertTrue(recorder.administratorScripts.isEmpty)
    }

    func testPermissionDeniedFallsBackToAdministratorApproval() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder(directError: CocoaError(.fileWriteNoPermission))
        let uninstaller = makeUninstaller(recorder: recorder)

        try await uninstaller.uninstall(app)

        XCTAssertEqual(recorder.directRemovals, [app.standardizedFileURL])
        XCTAssertEqual(recorder.administratorScripts, [
            AppBundleUninstaller.administratorRemovalScript(for: app)
        ])
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

        XCTAssertTrue(recorder.directRemovals.isEmpty)
        XCTAssertTrue(recorder.administratorScripts.isEmpty)
    }

    func testNonPermissionFailureDoesNotRequestAdministratorApproval() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder(directError: CocoaError(.fileNoSuchFile))
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected direct removal failure to be preserved.")
        } catch {
            XCTAssertEqual((error as NSError).code, CocoaError.fileNoSuchFile.rawValue)
        }

        XCTAssertEqual(recorder.directRemovals, [app.standardizedFileURL])
        XCTAssertTrue(recorder.administratorScripts.isEmpty)
    }

    func testFailedAdministratorApprovalReportsMeaningfulOutput() async throws {
        let app = URL(fileURLWithPath: "/Applications/Cleaner.app", isDirectory: true)
        let recorder = AppBundleUninstallerRecorder(
            directError: CocoaError(.fileWriteNoPermission),
            administratorOutput: .init(exitCode: 1, output: "User canceled.\n")
        )
        let uninstaller = makeUninstaller(recorder: recorder)

        do {
            try await uninstaller.uninstall(app)
            XCTFail("Expected administrator failure to be reported.")
        } catch let error as AppBundleUninstallerError {
            guard case let .administratorApprovalFailed(url, message) = error else {
                return XCTFail("Expected administratorApprovalFailed error, got \(error).")
            }
            XCTAssertEqual(url, app.standardizedFileURL)
            XCTAssertEqual(message, "User canceled.")
        }
    }

    private func makeUninstaller(recorder: AppBundleUninstallerRecorder) -> AppBundleUninstaller {
        AppBundleUninstaller(
            removeDirectly: { url in try recorder.removeDirectly(url) },
            runAdministratorScript: { script in recorder.runAdministratorScript(script) }
        )
    }
}

private final class AppBundleUninstallerRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let directError: Error?
    private let administratorOutput: AppBundleUninstaller.CommandOutput
    private var _directRemovals: [URL] = []
    private var _administratorScripts: [String] = []

    init(
        directError: Error? = nil,
        administratorOutput: AppBundleUninstaller.CommandOutput = .init(exitCode: 0, output: "")
    ) {
        self.directError = directError
        self.administratorOutput = administratorOutput
    }

    var directRemovals: [URL] {
        lock.withLock { _directRemovals }
    }

    var administratorScripts: [String] {
        lock.withLock { _administratorScripts }
    }

    func removeDirectly(_ url: URL) throws {
        try lock.withLock {
            _directRemovals.append(url)
            if let directError { throw directError }
        }
    }

    func runAdministratorScript(_ script: String) -> AppBundleUninstaller.CommandOutput {
        lock.withLock {
            _administratorScripts.append(script)
            return administratorOutput
        }
    }
}
