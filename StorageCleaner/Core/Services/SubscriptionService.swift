import Foundation

// MARK: - Errors

enum SubscriptionServiceError: Error, LocalizedError, Equatable {
    case productNotFound(productID: String)
    case purchaseCancelled
    case purchasePending
    case purchaseFailed(message: String)
    case verificationFailed
    case restoreFailed(message: String)

    var errorDescription: String? {
        switch self {
        case let .productNotFound(productID):
            "Plan '\(productID)' is not available in the App Store."
        case .purchaseCancelled:
            "Purchase was cancelled."
        case .purchasePending:
            "Purchase is pending approval."
        case let .purchaseFailed(message):
            "Purchase failed: \(message)"
        case .verificationFailed:
            "We couldn't verify this purchase. Please try again."
        case let .restoreFailed(message):
            "Restore failed: \(message)"
        }
    }
}

// MARK: - Outcome models

/// The result of a `purchase(_:)` call. Carries enough context for the
/// paywall VM to update its UI and entitlement stream without re-querying
/// StoreKit.
enum PurchaseOutcome: Sendable, Equatable {
    case purchased(SubscriptionEntitlement)
    case pending
    case cancelled
}

/// A plan surfaced to the paywall. Localized display strings and prices
/// come from StoreKit — the paywall never hard-codes a currency symbol
/// or amount. Display fallback (when the App Store hasn't returned a
/// price yet) is computed from the product id.
struct SubscriptionPlan: Sendable, Identifiable, Equatable {
    let id: String
    let entitlement: SubscriptionEntitlement
    /// Localized display name (e.g. "Storage Cleaner Pro Monthly").
    let displayName: String
    /// Localized description (e.g. "Unlock cleanup across all categories").
    let description: String
    /// Formatted price as returned by StoreKit (e.g. "$4.99", "€5,99").
    /// Always localized to the user's storefront.
    let displayPrice: String
    /// Billing period the user is committing to. `.lifetime` for
    /// non-consumables. `nil` for plans StoreKit hasn't priced yet.
    let period: BillingPeriod?

    enum BillingPeriod: String, Sendable, Equatable, Codable {
        case monthly
        case yearly
        case lifetime

        var displayLabel: String {
            switch self {
            case .monthly: "/ month"
            case .yearly: "/ year"
            case .lifetime: "one-time"
            }
        }
    }
}

// MARK: - Service protocol

/// The single seam between the app and whatever StoreKit (or test
/// double) is doing the IAP work. `Sendable` so the dashboard's
/// view model can hold a reference from the main actor while the
/// service's purchase calls suspend on StoreKit's background work.
///
/// `currentEntitlement()` and `entitlementUpdates()` together form the
/// read side: callers snapshot on demand and subscribe for changes.
/// `loadProducts()` and `purchase(_:)` / `restore()` are the write /
/// network side.
///
/// `showManageSubscriptions()` is the only MainActor-isolated member
/// because it ultimately calls into AppKit (`AppStore.showManageSubscriptions`)
/// to surface the system sheet.
protocol SubscriptionService: AnyObject, Sendable {
    /// The current entitlement as known by the service at call time.
    /// Prefer `entitlementUpdates()` for live UI.
    func currentEntitlement() async -> SubscriptionEntitlement

    /// A hot stream of entitlement changes. The store starts in `.free`
    /// and emits a new value whenever a transaction is verified (initial
    /// purchase, renewal, restore, refund, or revocation).
    func entitlementUpdates() -> AsyncStream<SubscriptionEntitlement>

    /// Fetches the configured products from StoreKit. Returns whatever
    /// is currently available — products that aren't approved yet in
    /// App Store Connect are simply absent.
    func loadProducts() async throws -> [SubscriptionPlan]

    /// Initiates a purchase for the given product id. Throws
    /// `SubscriptionServiceError.purchaseCancelled` when the user
    /// explicitly cancels the StoreKit sheet.
    func purchase(productID: String) async throws -> PurchaseOutcome

    /// Restores prior purchases from the user's App Store account.
    /// Always succeeds in returning an up-to-date entitlement state,
    /// even when nothing was restored.
    func restore() async throws -> SubscriptionEntitlement

    /// Opens the system "Manage Subscriptions" sheet via AppKit.
    /// Always callable — if the user has no active subscriptions the
    /// App Store will just show their account page.
    @MainActor
    func showManageSubscriptions()
}
