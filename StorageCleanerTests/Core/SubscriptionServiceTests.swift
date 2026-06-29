import XCTest
@testable import StorageCleaner

@MainActor
final class SubscriptionControllerTests: XCTestCase {
    private var service: MockSubscriptionService!
    private var controller: SubscriptionController!

    override func setUp() async throws {
        service = MockSubscriptionService()
        controller = SubscriptionController(service: service)
    }

    /// Lets the controller's entitlement stream settle to `target`.
    /// Required because `setEntitlement(_:)` on the service is
    /// synchronous, but the stream consumer picks up the change on
    /// a later scheduler tick.
    private func waitForEntitlement(_ target: SubscriptionEntitlement) async {
        for _ in 0..<50 where controller.currentEntitlement != target {
            await Task.yield()
        }
        XCTAssertEqual(controller.currentEntitlement, target)
    }

    // MARK: - Initial state

    func testInitialEntitlementIsFree() async {
        await waitForEntitlement(.free)
        XCTAssertNil(controller.paywallRequest)
    }

    // MARK: - Paywall request

    func testPresentPaywallSetsTrigger() {
        controller.presentPaywall(trigger: .gatedAction)
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testDismissPaywallClearsTrigger() {
        controller.presentPaywall(trigger: .gatedAction)
        controller.dismissPaywall()
        XCTAssertNil(controller.paywallRequest)
    }

    func testPresentPaywallCoalescesWhenAlreadyPresented() {
        controller.presentPaywall(trigger: .gatedAction)
        controller.presentPaywall(trigger: .manualOpen)
        // First call wins; the user is already inside a paywall
        // and shouldn't be popped into a new one mid-flow.
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testRequireProRequestsPaywallForFreeUser() {
        XCTAssertFalse(controller.requirePro(trigger: .gatedAction))
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testRequireProAllowsActiveEntitlement() async {
        service.setEntitlement(.yearly)
        await waitForEntitlement(.yearly)

        XCTAssertTrue(controller.requirePro(trigger: .gatedAction))
        XCTAssertNil(controller.paywallRequest)
    }

    // MARK: - Stream updates

    func testEntitlementStreamUpdatesController() async {
        await waitForEntitlement(.free)
        service.setEntitlement(.yearly)
        await waitForEntitlement(.yearly)
    }

    func testMultipleSubscribersAllReceiveUpdates() async {
        let second = SubscriptionController(service: service)
        // Both controllers should be at .free initially.
        for _ in 0..<20 where controller.currentEntitlement != .free || second.currentEntitlement != .free {
            await Task.yield()
        }
        service.setEntitlement(.lifetime)
        for _ in 0..<50 where controller.currentEntitlement != .lifetime || second.currentEntitlement != .lifetime {
            await Task.yield()
        }
        XCTAssertEqual(controller.currentEntitlement, .lifetime)
        XCTAssertEqual(second.currentEntitlement, .lifetime)
    }
}

@MainActor
final class DashboardViewModelSubscriptionGateTests: XCTestCase {
    private var service: MockSubscriptionService!
    private var controller: SubscriptionController!
    private var cleanup: StubCleanupService!

    override func setUp() async throws {
        service = MockSubscriptionService()
        controller = SubscriptionController(service: service)
        cleanup = StubCleanupService(reclaimedBytesByURL: [:])
    }

    /// Lets the controller's stream reflect `target` before we
    /// construct a VM. The gate checks `controller.currentEntitlement`
    /// synchronously, so a flake-free test needs the controller in
    /// the right state at construction time.
    private func setEntitlementAndWait(_ target: SubscriptionEntitlement) async {
        service.setEntitlement(target)
        for _ in 0..<50 where controller.currentEntitlement != target {
            await Task.yield()
        }
        XCTAssertEqual(controller.currentEntitlement, target)
    }

    func testFreeUserCleanupIsBlockedAndRequestsPaywall() async {
        await setEntitlementAndWait(.free)
        let viewModel = makeViewModel()
        let result = await viewModel.deleteFiles([URL(filePath: "/tmp/a")])

        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(result.totalBytesReclaimed, 0)
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testProUserCleanupProceeds() async {
        await setEntitlementAndWait(.monthly)
        let url = URL(filePath: "/tmp/some-file")
        cleanup = StubCleanupService(reclaimedBytesByURL: [url: 1_024])
        let viewModel = makeViewModel()
        let result = await viewModel.deleteFiles([url])

        XCTAssertEqual(result.deletedCount, 1)
        XCTAssertEqual(result.totalBytesReclaimed, 1_024)
        XCTAssertNil(controller.paywallRequest)
    }

    func testCLIProgramsCleanupIsAlsoGated() async {
        await setEntitlementAndWait(.free)
        let viewModel = makeViewModel()
        let result = await viewModel.removeCLIPrograms([URL(filePath: "/usr/local/bin/foo")])
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testRuntimeVersionsCleanupIsAlsoGated() async {
        await setEntitlementAndWait(.free)
        let viewModel = makeViewModel()
        let result = await viewModel.removeRuntimeVersions([URL(filePath: "/Users/x/.nvm/versions/node/v18.0.0")])
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(controller.paywallRequest, .gatedAction)
    }

    func testCleanupWithoutControllerAlwaysProceeds() async {
        // No controller wired — legacy behavior is preserved so old
        // unit tests that don't care about subscriptions keep working.
        let viewModel = DashboardViewModel(
            scanner: EmptyStreamScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: cleanup,
            historyStore: nil,
            subscriptionController: nil
        )
        let result = await viewModel.deleteFiles([URL(filePath: "/tmp/a")])
        XCTAssertEqual(result.deletedCount, 1)
    }

    func testCanCleanupMirrorsEntitlement() async {
        await setEntitlementAndWait(.free)
        XCTAssertFalse(makeViewModel().canCleanup)
        await setEntitlementAndWait(.monthly)
        XCTAssertTrue(makeViewModel().canCleanup)
        await setEntitlementAndWait(.yearly)
        XCTAssertTrue(makeViewModel().canCleanup)
        await setEntitlementAndWait(.lifetime)
        XCTAssertTrue(makeViewModel().canCleanup)
    }

    // MARK: - Helpers

    private func makeViewModel() -> DashboardViewModel {
        DashboardViewModel(
            scanner: EmptyStreamScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: cleanup,
            historyStore: nil,
            subscriptionController: controller
        )
    }
}
