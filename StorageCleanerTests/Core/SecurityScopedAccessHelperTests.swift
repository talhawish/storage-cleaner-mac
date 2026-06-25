import XCTest
@testable import StorageCleaner

/// Coverage for the shared `StoragePermissionHandling.withHomeFolderAccess`
/// helper that the dashboard's `SecurityScopedCategoryScanner` and
/// `QuickCleanScanner` both use to acquire/release the home-folder security
/// scope in one place.
final class SecurityScopedAccessHelperTests: XCTestCase {
    /// When the user has granted access, the body must run with a
    /// non-nil token, and the token must be released on return.
    func testHelperRunsBodyAndReleasesScopeWhenAccessIsGranted() async {
        let recorder = ScopeLifecycleRecorder()
        let handler = GrantingPermissionHandler(lifecycle: recorder)
        let captured = await captureAccess(from: handler, returning: 42)

        XCTAssertEqual(captured.value, 42)
        XCTAssertTrue(captured.accessWasGranted)
        XCTAssertEqual(recorder.beginCount, 1)
        XCTAssertEqual(recorder.stopCount, 1)
    }

    /// When the user has not granted access, the body must still run (so
    /// the caller can decide what to do — render a permission prompt, etc.)
    /// but it must receive a `nil` access token.
    func testHelperRunsBodyWithNilAccessWhenAccessIsDenied() async {
        let handler = DenyingPermissionHandler()
        let captured = await captureAccess(from: handler, returning: "scanned")

        XCTAssertEqual(captured.value, "scanned")
        XCTAssertFalse(captured.accessWasGranted)
    }

    /// Runs the body with a sentinel value and records whether the access
    /// token was non-nil. Wrapping in a helper avoids the optional-boolean
    /// anti-pattern while keeping the assertion readable.
    private func captureAccess<T: Sendable>(
        from handler: DenyingPermissionHandler,
        returning sentinel: T
    ) async -> (value: T, accessWasGranted: Bool) {
        var granted = false
        let value: T = await handler.withHomeFolderAccess { access in
            granted = (access != nil)
            return sentinel
        }
        return (value, granted)
    }

    private func captureAccess<T: Sendable>(
        from handler: GrantingPermissionHandler,
        returning sentinel: T
    ) async -> (value: T, accessWasGranted: Bool) {
        var granted = false
        let value: T = await handler.withHomeFolderAccess { access in
            granted = (access != nil)
            return sentinel
        }
        return (value, granted)
    }

    /// `beginHomeFolderAccess()` must be called exactly once per
    /// `withHomeFolderAccess` invocation. Calling it twice is wasteful and
    /// could break tests / handlers that count invocations.
    func testHelperCallsBeginHomeFolderAccessExactlyOnce() async {
        let recorder = ScopeLifecycleRecorder()
        let handler = GrantingPermissionHandler(lifecycle: recorder)

        _ = await handler.withHomeFolderAccess { _ in }
        _ = await handler.withHomeFolderAccess { _ in }

        XCTAssertEqual(recorder.beginCount, 2)
    }
}

// MARK: - Fixtures

private final class ScopeLifecycleRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var begin = 0
    private var stop = 0

    var beginCount: Int { lock.withLock { begin } }
    var stopCount: Int { lock.withLock { stop } }

    func recordBegin() { lock.withLock { begin += 1 } }
    func recordStop() { lock.withLock { stop += 1 } }
}

private final class GrantingPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    private let lifecycle: ScopeLifecycleRecorder
    init(lifecycle: ScopeLifecycleRecorder) { self.lifecycle = lifecycle }

    func currentStatuses() -> [StoragePermissionStatus] { [] }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        lifecycle.recordBegin()
        return SecurityScopedResourceAccess(onStop: { [lifecycle] in
            lifecycle.recordStop()
        })
    }
}

private final class DenyingPermissionHandler: StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] { [] }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? { nil }
}
