import Foundation
import Observation

/// Drives the paywall sheet: the marketing copy on the left, the plan
/// cards on the right, the restore / purchase / error affordances.
///
/// Responsibilities:
/// - Subscribe to the service's entitlement stream so the paywall
///   auto-dismisses when the user successfully purchases or restores.
/// - Fetch the live product catalog from the service on appear and
///   fall back to the service's static catalog if StoreKit hasn't
///   returned anything yet (e.g. product not approved in App Store
///   Connect during development).
/// - Track per-plan purchase state so each card can show its own
///   spinner without blocking the others.
/// - Surface a single transient banner (success / error) at the top
///   of the modal rather than alert spam.
///
/// The VM is `@Observable` and `@MainActor`-isolated; views read
/// `plans`, `currentEntitlement`, `activeProductID`, and `banner` as
/// normal properties and SwiftUI handles the rest.
@MainActor
@Observable
final class PaywallViewModel {
    enum Banner: Equatable {
        case none
        case success(message: String)
        case error(message: String)
        case info(message: String)
    }

    /// The product id currently being purchased. `nil` means nothing
    /// in flight. The view binds this to per-card spinner state.
    private(set) var purchasingProductID: String?
    /// The product id currently being restored. Excluded from
    /// `purchasingProductID` so the restore button can show its own
    /// spinner even when another action is in flight (we want the
    /// restore to be its own affordance).
    private(set) var restoring: Bool = false
    private(set) var plans: [SubscriptionPlan] = []
    private(set) var currentEntitlement: SubscriptionEntitlement = .free
    private(set) var banner: Banner = .none
    /// `true` until the initial `loadProducts()` resolves. Drives the
    /// plan column's skeleton state.
    private(set) var isLoadingProducts = true
    /// The plan to visually highlight as "best value" / "most popular".
    /// Defaults to yearly (the middle option) which converts best in
    /// our price ladder; the value is recomputed once plans arrive.
    private(set) var highlightedPlanID: String = SubscriptionProductID.yearly

    private let service: any SubscriptionService
    private let onEntitlementUpgraded: (@MainActor () -> Void)?
    private let onDismiss: (@MainActor () -> Void)?
    private var entitlementTask: Task<Void, Never>?

    init(
        service: any SubscriptionService,
        onEntitlementUpgraded: (@MainActor () -> Void)? = nil,
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        self.service = service
        self.onEntitlementUpgraded = onEntitlementUpgraded
        self.onDismiss = onDismiss
        subscribeToEntitlementStream()
    }

    // No deinit: see SubscriptionController — the entitlement Task
    // captures self weakly, so the for-await loop exits naturally
    // once the VM is gone. Avoids a Swift 6 concurrency conflict
    // where a nonisolated deinit cannot touch MainActor state.

    // MARK: - Lifecycle

    /// Fetches the live product catalog. Safe to call multiple times
    /// (e.g. on retry after an error) — the service caches by product
    /// id so repeat calls are cheap.
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await service.loadProducts()
            plans = loaded.isEmpty ? fallbackPlans() : loaded
        } catch {
            plans = fallbackPlans()
            banner = .error(message: "Couldn't load plans. You can still try a purchase below.")
        }
    }

    /// Initiates a purchase for the given product id. The card's
    /// spinner is driven by `purchasingProductID`; on success the
    /// entitlement stream fires and the banner + dismiss happen
    /// automatically.
    func purchase(productID: String) async {
        guard purchasingProductID == nil else { return }
        purchasingProductID = productID
        banner = .none
        defer { purchasingProductID = nil }

        do {
            let outcome = try await service.purchase(productID: productID)
            switch outcome {
            case .purchased(let entitlement):
                currentEntitlement = entitlement
                banner = .success(message: successMessage(for: entitlement))
                onEntitlementUpgraded?()
            case .pending:
                banner = .info(
                    message: "Your purchase is pending approval. We'll unlock Pro once it's confirmed."
                )
            case .cancelled:
                banner = .info(message: "Purchase cancelled.")
            }
        } catch SubscriptionServiceError.purchaseCancelled {
            banner = .info(message: "Purchase cancelled.")
        } catch let error as SubscriptionServiceError {
            banner = .error(message: error.errorDescription ?? "Something went wrong.")
        } catch {
            banner = .error(message: error.localizedDescription)
        }
    }

    /// Restores prior purchases. The button is always visible so a
    /// user who bought on another device can re-claim their
    /// entitlement; tapping it never throws a "nothing to restore"
    /// error, it just no-ops and shows an info banner.
    func restore() async {
        guard !restoring else { return }
        restoring = true
        banner = .none
        defer { restoring = false }

        do {
            let entitlement = try await service.restore()
            currentEntitlement = entitlement
            if entitlement == .free {
                banner = .info(
                    message: "No previous purchases found on this Apple ID."
                )
            } else {
                banner = .success(message: successMessage(for: entitlement))
                onEntitlementUpgraded?()
            }
        } catch let error as SubscriptionServiceError {
            banner = .error(message: error.errorDescription ?? "Couldn't restore purchases.")
        } catch {
            banner = .error(message: error.localizedDescription)
        }
    }

    func dismiss() {
        onDismiss?()
    }

    func clearBanner() {
        banner = .none
    }

    /// Whether the upgrade should auto-dismiss the sheet. When the
    /// user already had a different Pro plan and purchased the same
    /// or higher tier we close immediately; when the user is just
    /// browsing we keep the sheet open so they see the success state.
    var shouldAutoDismissOnPurchase: Bool {
        currentEntitlement == .free
    }

    // MARK: - Stream

    private func subscribeToEntitlementStream() {
        entitlementTask?.cancel()
        let stream = service.entitlementUpdates()
        entitlementTask = Task { [weak self] in
            for await entitlement in stream {
                guard let self else { return }
                self.currentEntitlement = entitlement
                if entitlement != .free {
                    self.banner = .success(
                        message: self.successMessage(for: entitlement)
                    )
                    if self.shouldAutoDismissOnPurchase {
                        self.onEntitlementUpgraded?()
                    }
                }
            }
        }
    }

    // MARK: - Derived

    private func successMessage(for entitlement: SubscriptionEntitlement) -> String {
        switch entitlement {
        case .free: ""
        case .monthly: "Storage Cleaner Pro (Monthly) is now active. Thanks!"
        case .yearly: "Storage Cleaner Pro (Yearly) is now active. Thanks!"
        case .lifetime: "Storage Cleaner Pro (Lifetime) is now active. Thanks!"
        }
    }

    /// Used as a last-resort catalog when StoreKit hasn't returned
    /// anything (sandbox, unconfigured product, network blip). The
    /// prices are the App Store default tier and the product ids
    /// still match the real ones, so a later `loadProducts()` that
    /// succeeds simply replaces this catalog in place.
    private func fallbackPlans() -> [SubscriptionPlan] {
        [
            SubscriptionPlan(
                id: SubscriptionProductID.monthly,
                entitlement: .monthly,
                displayName: "Monthly",
                description: "Unlock Pro features, billed monthly.",
                displayPrice: "$4.99",
                period: .monthly
            ),
            SubscriptionPlan(
                id: SubscriptionProductID.yearly,
                entitlement: .yearly,
                displayName: "Yearly",
                description: "Unlock Pro for a full year — best value.",
                displayPrice: "$29.99",
                period: .yearly
            ),
            SubscriptionPlan(
                id: SubscriptionProductID.lifetime,
                entitlement: .lifetime,
                displayName: "Lifetime",
                description: "One purchase, yours forever.",
                displayPrice: "$49.99",
                period: .lifetime
            )
        ]
    }
}
