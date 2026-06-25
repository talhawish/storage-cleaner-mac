import Foundation
import XCTest
@testable import StorageCleaner

@MainActor
final class EmulatorsViewModelTests: XCTestCase {
    /// In-process fake. Doesn't touch the filesystem or spawn `xcrun`, so the view model's
    /// state machine is testable in isolation.
    private final class FakeEmulatorService: EmulatorsServicing, @unchecked Sendable {
        var discoverCalls = 0
        var measureCalls = 0
        var nextDiscover: [EmulatorImage] = []
        var nextMeasure: [EmulatorImage] = []
        var removeCalls: [[EmulatorImage]] = []
        var nextRemove: EmulatorCleanupResult = .init(removedIDs: [], totalBytesReclaimed: 0, failures: [])

        func discover() async -> [EmulatorImage] {
            discoverCalls += 1
            return nextDiscover
        }

        func measuringRemainingSizes(in images: [EmulatorImage]) -> [EmulatorImage] {
            measureCalls += 1
            return nextMeasure.isEmpty ? images : nextMeasure
        }

        func remove(_ images: [EmulatorImage]) async -> EmulatorCleanupResult {
            removeCalls.append(images)
            return nextRemove
        }
    }

    private func runtime(id: String = "rt-1", version: String = "26.5") -> EmulatorImage {
        EmulatorImage(
            id: id,
            platform: .appleSimulator,
            title: "iOS \(version)",
            versionLabel: version,
            key: VersionKey.parse(version),
            bytes: 8_000_000_000,
            detail: "Build 23F77",
            removal: .simctlRuntime(identifier: id),
            isRemovable: true,
            lastUsed: Date()
        )
    }

    private func deviceSupport(id: String = "ds-1", version: String = "26.5") -> EmulatorImage {
        EmulatorImage(
            id: id,
            platform: .iosDeviceSupport,
            title: "iOS \(version)",
            versionLabel: version,
            key: VersionKey.parse(version),
            bytes: 5_000_000_000,
            detail: "Build 23F77",
            removal: .trashDirectory(URL(fileURLWithPath: "/tmp/\(id)")),
            isRemovable: true,
            lastUsed: nil
        )
    }

    private func grantedHandler() -> StoragePermissionHandling {
        GrantedPermissionHandler()
    }

    // MARK: - Initial state

    /// The view should always start in `.loading` so the spinner is visible the moment the
    /// view is rendered. A regression that initialized `state = .empty` would skip the loading
    /// affordance — the bug the user reported.
    func testStartsInLoadingState() {
        let viewModel = EmulatorsViewModel(service: FakeEmulatorService())
        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertTrue(viewModel.images.isEmpty)
    }

    // MARK: - Loading transitions

    func testStartTransitionsThroughLoadingToLoadedWithContent() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime(), deviceSupport()]

        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())
        viewModel.start()

        // Wait for the load to complete (the view model holds the loading state for at least
        // 0.4s so the spinner is perceptible).
        try? await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.images.count, 2)
        XCTAssertGreaterThanOrEqual(service.discoverCalls, 1)
    }

    func testStartTransitionsToEmptyWhenDiscoverReturnsNothing() async {
        let service = FakeEmulatorService()
        service.nextDiscover = []

        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())
        viewModel.start()

        try? await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertTrue(viewModel.images.isEmpty)
    }

    /// The minimum loading duration (400 ms) must be enforced so a fast machine still shows
    /// the spinner. Without this guard, the user would see the empty / content state with no
    /// loading affordance — the exact bug they reported.
    func testLoadingStateIsVisibleForAtLeastFourHundredMilliseconds() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime()]
        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())

        let started = Date()
        viewModel.start()

        // Poll state every 50 ms until it leaves loading, and record when it left.
        for _ in 0..<40 {
            if viewModel.state != .loading { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertGreaterThanOrEqual(elapsed, 0.4, "loading state must remain visible for at least 400 ms")
        XCTAssertEqual(viewModel.state, .loaded)
    }

    /// The Rescan button calls `start()` again. We verify the previous load is cancelled and
    /// a fresh discovery runs.
    func testStartTwiceTriggersTwoDiscoveries() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime()]

        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(700))

        service.nextDiscover = [runtime(version: "26.4")]
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(service.discoverCalls, 2, "every start() must call discover() exactly once")
    }

    // MARK: - Selection

    func testToggleAddsAndRemovesSelection() {
        let service = FakeEmulatorService()
        let viewModel = EmulatorsViewModel(service: service)
        let image = runtime()

        viewModel.toggle(image)
        XCTAssertTrue(viewModel.selectedIDs.contains(image.id))

        viewModel.toggle(image)
        XCTAssertFalse(viewModel.selectedIDs.contains(image.id))
    }

    func testToggleAllFlipsEveryRemovableImage() {
        let service = FakeEmulatorService()
        let viewModel = EmulatorsViewModel(service: service)
        let images = [runtime(id: "a"), runtime(id: "b"), runtime(id: "c")]

        viewModel.toggleAll(in: images)
        XCTAssertEqual(viewModel.selectedIDs, Set(["a", "b", "c"]))

        viewModel.toggleAll(in: images)
        XCTAssertTrue(viewModel.selectedIDs.isEmpty)
    }

    // MARK: - Sections

    func testSectionsAreSortedByPlatformAndContainOnlyPresentItems() async {
        let service = FakeEmulatorService()
        let runtime = self.runtime()
        let device = self.deviceSupport()
        let simulator = EmulatorImage(
            id: "sim-1",
            platform: .simulatorDevices,
            title: "iPhone 17 Pro",
            versionLabel: "iOS 26.5",
            key: VersionKey.parse("26.5"),
            bytes: 9_500_000_000,
            detail: "Orphaned simulator device",
            removal: .trashDirectory(URL(fileURLWithPath: "/tmp/sim-1")),
            isRemovable: true,
            lastUsed: nil
        )
        service.nextDiscover = [simulator, runtime, device]
        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(700))

        let platforms = viewModel.sections.map(\.platform)
        XCTAssertEqual(platforms, [.appleSimulator, .simulatorDevices, .iosDeviceSupport])
    }

    // MARK: - Deletion

    func testDeleteForwardsToServiceAndClearsSelection() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime(), deviceSupport()]
        let viewModel = EmulatorsViewModel(service: service, permissionHandler: grantedHandler())
        viewModel.start()
        try? await Task.sleep(for: .milliseconds(700))

        viewModel.selectedIDs = [runtime().id, deviceSupport().id]
        let toRemove = viewModel.selectedImages

        _ = await viewModel.delete(toRemove)

        XCTAssertEqual(service.removeCalls.count, 1)
        XCTAssertEqual(service.removeCalls.first?.count, 2)
    }

    // MARK: - Live wiring

    /// End-to-end: spin the real `EmulatorManagementService.live` through the view model on the
    /// developer's actual Mac. The previous bug — the view showing the empty state directly —
    /// happened because no test exercised this path, so a mis-wired `live` factory went
    /// unnoticed. This test fails fast if `discover()` returns nothing on a real machine.
    func testLiveServiceTransitionsToLoadedOnDeveloperMac() async throws {
        let viewModel = EmulatorsViewModel(service: EmulatorManagementService.live)
        viewModel.start()

        for _ in 0..<20 {
            if viewModel.state != .loading { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNotEqual(
            viewModel.state,
            .empty,
            "EmulatorManagementService.live.discover() returned no images — the view model would " +
            "show the empty state. Check that DependencyPaths.Apple points at the right folders."
        )
    }

    // MARK: - Sandbox / security-scoped access

    /// The Emulators view reads from `~/Library/Developer/Xcode/iOS DeviceSupport/`,
    /// `~/Library/Developer/CoreSimulator/Devices/`, etc. None of these are reachable inside a
    /// sandboxed `.app` without an active security-scoped bookmark on the home folder — without
    /// it, `discover()` silently returns `[]` and the user sees the empty state for 50+ GB of
    /// reclaimable data. This test pins the wiring: every `start()` must acquire home folder
    /// access (or no-op it in tests) before calling `discover()`.
    func testStartAcquiresHomeFolderAccessBeforeDiscovery() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime()]
        let handler = RecordingPermissionHandler()
        let viewModel = EmulatorsViewModel(
            service: service,
            permissionHandler: handler
        )
        viewModel.start()

        try? await Task.sleep(for: .milliseconds(700))

        XCTAssertGreaterThanOrEqual(
            handler.beginCallCount,
            1,
            "load() must call permissionHandler.beginHomeFolderAccess() so a sandboxed build " +
            "can read ~/Library/Developer/Xcode. Without this call, the Emulators view shows the " +
            "empty state for what is actually tens of GB of reclaimable data."
        )
    }

    func testStartStillWorksWhenPermissionHandlerReturnsNil() async {
        // Unsandboxed builds (and tests) get nil from beginHomeFolderAccess(). The load must
        // still complete and surface the discovered items so the view shows them, even without
        // an active security scope.
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime(), deviceSupport()]
        let handler = DenyingPermissionHandler()
        let viewModel = EmulatorsViewModel(
            service: service,
            permissionHandler: handler
        )
        viewModel.start()

        try? await Task.sleep(for: .milliseconds(700))

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.images.count, 2)
    }

    // MARK: - Permission-required state

    func testStartShowsPermissionRequiredWhenHomeAccessDenied() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime()]
        let handler = BlockedPermissionHandler()
        let viewModel = EmulatorsViewModel(
            service: service,
            permissionHandler: handler
        )
        viewModel.start()

        // Should transition directly to permissionRequired without loading.
        XCTAssertEqual(viewModel.state, .permissionRequired)
        XCTAssertTrue(viewModel.images.isEmpty)
        XCTAssertEqual(service.discoverCalls, 0, "discover must not be called when permission is blocked")
    }

    func testGrantAccessAndRetryResumesLoading() async {
        let service = FakeEmulatorService()
        service.nextDiscover = [runtime()]
        let homeURL = URL(fileURLWithPath: "/Users/test")
        let deniedStatuses: [StoragePermissionStatus] = [
            StoragePermissionStatus(scope: .home, url: homeURL, state: .denied)
        ]
        let handler = SimulatedHomeGrantHandler(statuses: deniedStatuses)
        let viewModel = EmulatorsViewModel(
            service: service,
            permissionHandler: handler
        )
        viewModel.start()
        XCTAssertEqual(viewModel.state, .permissionRequired)

        // Simulate the user granting access, then retry.
        handler.granted = true
        handler.statuses = [
            StoragePermissionStatus(scope: .home, url: homeURL, state: .accessible)
        ]
        viewModel.grantAccessAndRetry()

        try? await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(service.discoverCalls, 1)
    }
}

// MARK: - Permission handlers

/// Reports home as accessible so `start()` proceeds to discovery. Used by tests that need
/// the load path but don't care about permission gating.
private final class GrantedPermissionHandler: StoragePermissionHandling, @unchecked Sendable {
    func currentStatuses() -> [StoragePermissionStatus] {
        [StoragePermissionStatus(scope: .home, url: URL(fileURLWithPath: "/Users/test"), state: .accessible)]
    }

    func requestHomeFolderAccess() -> Bool { false }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? { nil }
}

/// Records every call so tests can assert the view model actually goes through the permission
/// handler. Returns `nil` for the access (mirrors the unsandboxed / test path).
private final class RecordingPermissionHandler: StoragePermissionHandling, @unchecked Sendable {
    private(set) var beginCallCount = 0
    func currentStatuses() -> [StoragePermissionStatus] { [] }
    func requestHomeFolderAccess() -> Bool { false }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        beginCallCount += 1
        return nil
    }
}

/// Always denies access. The view model must still complete the load — denying access is a
/// valid state (e.g. an unsandboxed test build), it just means we don't have a scope active.
private final class DenyingPermissionHandler: StoragePermissionHandling, @unchecked Sendable {
    func currentStatuses() -> [StoragePermissionStatus] { [] }
    func requestHomeFolderAccess() -> Bool { false }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? { nil }
}

/// Reports the home scope as `.denied` so `start()` transitions to `.permissionRequired`.
private final class BlockedPermissionHandler: StoragePermissionHandling, @unchecked Sendable {
    func currentStatuses() -> [StoragePermissionStatus] {
        [StoragePermissionStatus(scope: .home, url: URL(fileURLWithPath: "/Users/test"), state: .denied)]
    }

    func requestHomeFolderAccess() -> Bool { false }
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? { nil }
}

/// Simulates the full grant-and-retry lifecycle for the permission-required state machine.
private final class SimulatedHomeGrantHandler: StoragePermissionHandling, @unchecked Sendable {
    var statuses: [StoragePermissionStatus]
    var granted = false

    init(statuses: [StoragePermissionStatus]) { self.statuses = statuses }

    func currentStatuses() -> [StoragePermissionStatus] { statuses }

    func requestHomeFolderAccess() -> Bool { granted }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        guard granted else { return nil }
        return SecurityScopedResourceAccess(url: URL(fileURLWithPath: "/tmp/stub"), didStartAccessing: false)
    }
}
