import AppKit
import Foundation
import os
@testable import StorageCleaner

/// A controllable `SubscriptionService` for unit tests. The test
/// injects one of these into a `PaywallViewModel` / `SubscriptionController`
/// and uses `setEntitlement(_:)` to simulate user actions without
/// hitting real StoreKit.
///
/// Apple's official `StoreKitTest.TestStore` covers integration
/// tests against a real `.storekit` configuration; this mock is
/// for fast unit tests of view-model behavior (banner state,
/// purchase flow, restore, entitlement stream behavior) where
/// spinning up a TestStore would be overkill.
final class MockSubscriptionService: SubscriptionService, @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private var entitlement: SubscriptionEntitlement
    private var continuations: [UUID: AsyncStream<SubscriptionEntitlement>.Continuation] = [:]
    let productCatalog: [SubscriptionPlan]
    var purchaseDelay: Duration = .zero
    /// If set, `purchase(productID:)` throws this error instead of
    /// succeeding. Used to exercise the error UI.
    var purchaseError: SubscriptionServiceError?
    /// If set, `restore()` throws this error instead of returning
    /// the current entitlement.
    var restoreError: SubscriptionServiceError?

    init(initialEntitlement: SubscriptionEntitlement = .free) {
        self.entitlement = initialEntitlement
        self.productCatalog = Self.defaultCatalog()
    }

    func setEntitlement(_ new: SubscriptionEntitlement) {
        lock.lock()
        let previous = entitlement
        entitlement = new
        let snapshot = Array(continuations.values)
        lock.unlock()

        guard previous != new else { return }
        for continuation in snapshot {
            continuation.yield(new)
        }
    }

    func currentEntitlement() async -> SubscriptionEntitlement {
        lock.withLock { entitlement }
    }

    func entitlementUpdates() -> AsyncStream<SubscriptionEntitlement> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            let initial = self.entitlement
            self.continuations[id] = continuation
            self.lock.unlock()
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    func loadProducts() async throws -> [SubscriptionPlan] {
        if purchaseDelay > .zero {
            try? await Task.sleep(for: purchaseDelay)
        }
        return productCatalog
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        if let purchaseError {
            throw purchaseError
        }
        if purchaseDelay > .zero {
            try? await Task.sleep(for: purchaseDelay)
        }
        guard let new = SubscriptionEntitlement.from(productID: productID) else {
            throw SubscriptionServiceError.productNotFound(productID: productID)
        }
        setEntitlement(new)
        return .purchased(new)
    }

    func restore() async throws -> SubscriptionEntitlement {
        if let restoreError { throw restoreError }
        if purchaseDelay > .zero {
            try? await Task.sleep(for: purchaseDelay)
        }
        return await currentEntitlement()
    }

    @MainActor
    func showManageSubscriptions() {
        // No-op in unit tests; the real `NSWorkspace.open` would
        // require a UI environment we don't have.
    }

    private static func defaultCatalog() -> [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: SubscriptionProductID.monthly,
                entitlement: .monthly,
                displayName: "Pro Monthly",
                description: "Unlock Pro features, billed monthly.",
                displayPrice: "$4.99",
                period: .monthly
            ),
            SubscriptionPlan(
                id: SubscriptionProductID.yearly,
                entitlement: .yearly,
                displayName: "Pro Yearly",
                description: "Unlock Pro for a full year — best value.",
                displayPrice: "$29.99",
                period: .yearly
            ),
            SubscriptionPlan(
                id: SubscriptionProductID.lifetime,
                entitlement: .lifetime,
                displayName: "Pro Lifetime",
                description: "One purchase, yours forever.",
                displayPrice: "$49.99",
                period: .lifetime
            )
        ]
    }
}
