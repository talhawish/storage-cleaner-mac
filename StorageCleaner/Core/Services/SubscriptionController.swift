import Foundation
import Observation

/// Why the paywall is being shown. Drives the headline copy and the
/// post-purchase dismiss behavior. Pure data so the controller can
/// hold one across the lifetime of the request.
enum PaywallTrigger: String, Sendable, Equatable, Codable, Identifiable {
    /// User tried a Pro action (cleanup) while on the Free tier.
    /// Headline leans on the value prop: "Unlock cleanup in one tap."
    case gatedAction
    /// User explicitly opened the paywall from Settings or a Pro
    /// upsell card. Headline leans on the plan comparison.
    case manualOpen

    var id: String { rawValue }
}

/// Single source of truth for the app's entitlement state. Lives
/// alongside `AppContainer` for the lifetime of the process so the
/// paywall sheet, the dashboard's cleanup gate, and the Settings
/// panel all see the same Pro/Free value at the same time.
///
/// `paywallRequest` is the only write the rest of the app does
/// against this controller. The view layer reads it as a binding
/// to decide whether to show the paywall sheet; setting it to `nil`
/// from the sheet's onDismiss dismisses the sheet.
@MainActor
@Observable
final class SubscriptionController {
    private(set) var currentEntitlement: SubscriptionEntitlement = .free
    private(set) var paywallRequest: PaywallTrigger?

    let service: any SubscriptionService
    private var entitlementTask: Task<Void, Never>?

    init(service: any SubscriptionService) {
        self.service = service
        subscribeToEntitlementStream()
    }

    // No deinit: the entitlement Task captures `self` weakly, so when
    // the controller is deallocated the task's `for await` simply
    // exits on the next iteration. A deinit would also conflict with
    // Swift 6 strict concurrency (can't touch MainActor state from a
    // nonisolated deinit).

    // MARK: - Public API

    /// Requests that the paywall sheet be presented. The dashboard
    /// and settings call this when the user lands in a state that
    /// should result in a purchase opportunity.
    func presentPaywall(trigger: PaywallTrigger) {
        // Coalesce: if a paywall is already up for *any* trigger, we
        // don't open a second one. The user can choose to dismiss
        // and reopen if they want a different headline.
        guard paywallRequest == nil else { return }
        paywallRequest = trigger
    }

    /// Returns whether a Pro-only action can continue. Free users are
    /// routed to the paywall and the caller must no-op the action.
    @discardableResult
    func requirePro(trigger: PaywallTrigger = .gatedAction) -> Bool {
        guard currentEntitlement.isPro else {
            presentPaywall(trigger: trigger)
            return false
        }
        return true
    }

    func dismissPaywall() {
        paywallRequest = nil
    }

    /// Open the system subscription management sheet (App Store →
    /// Manage Subscriptions). On the demo build this is a no-op.
    func showManageSubscriptions() {
        service.showManageSubscriptions()
    }

    // MARK: - Stream

    private func subscribeToEntitlementStream() {
        entitlementTask?.cancel()
        let stream = service.entitlementUpdates()
        entitlementTask = Task { [weak self] in
            for await entitlement in stream {
                self?.currentEntitlement = entitlement
            }
        }
    }
}
