import Foundation

/// Retains the last StoreKit-verified entitlement across launches. StoreKit remains the source of
/// truth: a successful entitlement refresh replaces this value, while a temporary StoreKit
/// timeout leaves it intact so an offline or briefly unavailable App Store never flashes Pro
/// customers back to Free.
///
/// `UserDefaults` documents thread-safe access; the value is additionally owned and called by the
/// StoreKit actor in production. The unchecked conformance only bridges Foundation's missing
/// `Sendable` annotation.
struct SubscriptionEntitlementCache: @unchecked Sendable {
    static let live = SubscriptionEntitlementCache(userDefaults: .standard)

    private static let defaultKey = "LastVerifiedSubscriptionEntitlement"
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults, key: String = SubscriptionEntitlementCache.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() -> SubscriptionEntitlement {
        guard let rawValue = userDefaults.string(forKey: key),
              let entitlement = SubscriptionEntitlement(rawValue: rawValue) else {
            return .free
        }
        return entitlement
    }

    func store(_ entitlement: SubscriptionEntitlement) {
        if entitlement == .free {
            userDefaults.removeObject(forKey: key)
        } else {
            userDefaults.set(entitlement.rawValue, forKey: key)
        }
    }
}
