import XCTest
@testable import StorageCleaner

@MainActor
final class PaywallViewModelTests: XCTestCase {
    private var service: MockSubscriptionService!
    private var upgradedCallbackCount = 0

    override func setUp() async throws {
        service = MockSubscriptionService()
        upgradedCallbackCount = 0
    }

    private func waitForEntitlement(
        _ viewModel: PaywallViewModel,
        _ target: SubscriptionEntitlement
    ) async {
        for _ in 0..<50 where viewModel.currentEntitlement != target {
            await Task.yield()
        }
        XCTAssertEqual(viewModel.currentEntitlement, target)
    }

    // MARK: - Initial state

    func testInitialStateIsFreeAndLoading() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.currentEntitlement, .free)
        XCTAssertTrue(viewModel.isLoadingProducts)
        XCTAssertTrue(viewModel.plans.isEmpty)
        XCTAssertNil(viewModel.purchasingProductID)
        XCTAssertFalse(viewModel.restoring)
        XCTAssertEqual(viewModel.banner, .none)
        XCTAssertEqual(viewModel.highlightedPlanID, SubscriptionProductID.yearly)
    }

    // MARK: - Product loading

    func testLoadProductsPopulatesPlanList() async {
        let viewModel = makeViewModel()
        await viewModel.loadProducts()
        XCTAssertFalse(viewModel.isLoadingProducts)
        XCTAssertEqual(viewModel.plans.count, 3)
        XCTAssertEqual(viewModel.plans.map(\.entitlement), [.monthly, .yearly, .lifetime])
    }

    func testLoadProductsFailureShowsErrorBanner() async {
        let failingService = ThrowingLoadService()
        let viewModel = PaywallViewModel(service: failingService)

        await viewModel.loadProducts()

        XCTAssertFalse(viewModel.isLoadingProducts)
        XCTAssertTrue(viewModel.plans.isEmpty)
        guard case let .error(message) = viewModel.banner else {
            return XCTFail("Expected error banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.contains("load failed"))
    }

    func testLoadProductsEmptyCatalogKeepsPlansEmpty() async {
        let emptyService = EmptyCatalogService()
        let viewModel = PaywallViewModel(service: emptyService)

        await viewModel.loadProducts()

        XCTAssertFalse(viewModel.isLoadingProducts)
        XCTAssertTrue(viewModel.plans.isEmpty)
    }

    // MARK: - Purchase

    func testPurchaseSuccessUpdatesEntitlementAndShowsSuccessBanner() async {
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.purchase(productID: SubscriptionProductID.yearly)

        XCTAssertEqual(viewModel.currentEntitlement, .yearly)
        XCTAssertNil(viewModel.purchasingProductID)
        guard case let .success(message) = viewModel.banner else {
            return XCTFail("Expected success banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.contains("Yearly"))
    }

    func testPurchaseErrorShowsErrorBanner() async {
        service.purchaseError = .verificationFailed
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.purchase(productID: SubscriptionProductID.monthly)

        XCTAssertEqual(viewModel.currentEntitlement, .free)
        XCTAssertNil(viewModel.purchasingProductID)
        guard case let .error(message) = viewModel.banner else {
            return XCTFail("Expected error banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.contains("verify"))
    }

    func testPurchaseCancelledShowsInfoBanner() async {
        service.purchaseError = .purchaseCancelled
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.purchase(productID: SubscriptionProductID.lifetime)

        guard case let .info(message) = viewModel.banner else {
            return XCTFail("Expected info banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.lowercased().contains("cancel"))
    }

    func testPurchaseForUnknownProductIDThrows() async {
        let viewModel = makeViewModel()
        await viewModel.loadProducts()
        await viewModel.purchase(productID: "not.a.real.product")

        guard case .error = viewModel.banner else {
            return XCTFail("Expected error banner for unknown product, got \(viewModel.banner)")
        }
    }

    func testPurchaseIsSingleFlightPerProduct() async {
        service.purchaseDelay = .milliseconds(50)
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        let task1 = Task { await viewModel.purchase(productID: SubscriptionProductID.monthly) }
        let task2 = Task { await viewModel.purchase(productID: SubscriptionProductID.monthly) }
        await task1.value
        await task2.value

        XCTAssertNil(viewModel.purchasingProductID)
    }

    // MARK: - Restore

    func testRestoreWithNoPriorPurchaseShowsInfoBanner() async {
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.restore()

        XCTAssertEqual(viewModel.currentEntitlement, .free)
        guard case let .info(message) = viewModel.banner else {
            return XCTFail("Expected info banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.lowercased().contains("no previous"))
    }

    func testRestoreReappliesExistingEntitlement() async {
        service.setEntitlement(.monthly)
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.restore()

        XCTAssertEqual(viewModel.currentEntitlement, .monthly)
        guard case let .success(message) = viewModel.banner else {
            return XCTFail("Expected success banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.contains("Monthly"))
    }

    func testRestoreErrorShowsErrorBanner() async {
        service.restoreError = .restoreFailed(message: "network down")
        let viewModel = makeViewModel()
        await viewModel.loadProducts()

        await viewModel.restore()

        guard case let .error(message) = viewModel.banner else {
            return XCTFail("Expected error banner, got \(viewModel.banner)")
        }
        XCTAssertTrue(message.lowercased().contains("network"))
    }

    // MARK: - Entitlement stream

    func testEntitlementStreamUpdatesViewModel() async {
        let viewModel = makeViewModel()
        await waitForEntitlement(viewModel, .free)

        service.setEntitlement(.lifetime)
        await waitForEntitlement(viewModel, .lifetime)
    }

    // MARK: - Auto-dismiss behavior

    func testAutoDismissOnPurchaseTriggersCallbackForFreeUser() async {
        let viewModel = makeViewModel()
        await viewModel.loadProducts()
        XCTAssertTrue(viewModel.shouldAutoDismissOnPurchase)

        await viewModel.purchase(productID: SubscriptionProductID.yearly)
        XCTAssertEqual(upgradedCallbackCount, 1)
    }

    func testAutoDismissDoesNotTriggerCallbackForExistingProUser() async {
        service.setEntitlement(.monthly)
        let viewModel = makeViewModel()
        await waitForEntitlement(viewModel, .monthly)
        await viewModel.loadProducts()
        XCTAssertFalse(viewModel.shouldAutoDismissOnPurchase)

        await viewModel.purchase(productID: SubscriptionProductID.yearly)
        XCTAssertEqual(upgradedCallbackCount, 1)
    }

    // MARK: - Helpers

    private func makeViewModel() -> PaywallViewModel {
        PaywallViewModel(
            service: service,
            onEntitlementUpgraded: { [weak self] in
                self?.upgradedCallbackCount += 1
            }
        )
    }
}

private final class ThrowingLoadService: SubscriptionService, @unchecked Sendable {
    func currentEntitlement() async -> SubscriptionEntitlement { .free }
    func entitlementUpdates() -> AsyncStream<SubscriptionEntitlement> {
        AsyncStream { $0.yield(.free); $0.finish() }
    }
    func loadProducts() async throws -> [SubscriptionPlan] {
        struct LoadBoom: Error, LocalizedError {
            let errorDescription: String? = "load failed"
        }
        throw LoadBoom()
    }
    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func restore() async throws -> SubscriptionEntitlement { await currentEntitlement() }

    @MainActor
    func showManageSubscriptions() {}
}

private final class EmptyCatalogService: SubscriptionService, @unchecked Sendable {
    func currentEntitlement() async -> SubscriptionEntitlement { .free }
    func entitlementUpdates() -> AsyncStream<SubscriptionEntitlement> {
        AsyncStream { $0.yield(.free); $0.finish() }
    }
    func loadProducts() async throws -> [SubscriptionPlan] { [] }
    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func restore() async throws -> SubscriptionEntitlement { await currentEntitlement() }

    @MainActor
    func showManageSubscriptions() {}
}
