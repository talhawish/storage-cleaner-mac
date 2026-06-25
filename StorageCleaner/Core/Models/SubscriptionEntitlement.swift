import Foundation

/// The current entitlement level of the running user. A single source of truth
/// that drives every paywall check, settings panel, and post-purchase refresh
/// across the app.
enum SubscriptionEntitlement: String, Sendable, Equatable, Codable, CaseIterable {
    /// No purchase on file. Cleanup and other Pro features are blocked.
    case free
    /// Active monthly auto-renewing subscription.
    case monthly
    /// Active yearly auto-renewing subscription.
    case yearly
    /// One-time non-consumable purchase (lifetime).
    case lifetime

    var isPro: Bool {
        self != .free
    }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var productID: String {
        switch self {
        case .free: ""
        case .monthly: SubscriptionProductID.monthly
        case .yearly: SubscriptionProductID.yearly
        case .lifetime: SubscriptionProductID.lifetime
        }
    }

    /// The product id of any plan that grants Pro access. Used to look up
    /// the matching `SubscriptionPlan` after StoreKit reports a purchase.
    static func from(productID: String) -> SubscriptionEntitlement? {
        switch productID {
        case SubscriptionProductID.monthly: .monthly
        case SubscriptionProductID.yearly: .yearly
        case SubscriptionProductID.lifetime: .lifetime
        default: nil
        }
    }
}

/// Centralized product identifiers. Keep in sync with App Store Connect
/// (My Apps → Storage Cleaner → Subscriptions/In-App Purchases). Tests pin
/// against these constants so a typo in App Store Connect surfaces as a
/// runtime test failure rather than a silent "Plan unavailable" in the UI.
enum SubscriptionProductID {
    static let monthly = "com.storagecleaner.developer.pro.monthly"
    static let yearly = "com.storagecleaner.developer.pro.yearly"
    static let lifetime = "com.storagecleaner.developer.pro.lifetime"

    /// The full ordered set the paywall queries. Order is meaningful: the
    /// paywall renders plans in this order (with the middle one as the
    /// "best value" highlight).
    static let all: [String] = [monthly, yearly, lifetime]
}

/// Which product the paywall should mark as the highlighted "best value".
/// Hardcoded here so the marketing choice is data-driven and unit-testable
/// rather than scattered through the view layer.
enum SubscriptionPlanHighlight: String, Sendable, Codable, CaseIterable {
    case bestValue
    case mostPopular
    case none
}
