import Foundation

/// Subscription-related view-model surface for the dashboard:
/// the cleanup gate, the read-only entitlement mirror, and the
/// `canCleanup` flag views can bind against.
///
/// Extracted to its own file to keep `DashboardViewModel.swift`
/// under SwiftLint's 620-line file-length error threshold.
extension DashboardViewModel {
    /// Read-only view of the current Pro/Free state. Mirrors the
    /// controller so views that need to render Pro-only affordances
    /// (e.g. dim a "Clean" button) can read it off the same VM they
    /// already observe. Returns `true` when no controller is wired,
    /// matching `gateCleanup()`'s "legacy tests are always Pro" stance.
    var currentEntitlement: SubscriptionEntitlement {
        subscriptionController?.currentEntitlement ?? .lifetime
    }

    /// Whether the user is allowed to clean. Views bind against this
    /// to gray out cleanup buttons; the dashboard's own delete
    /// methods also re-check via `gateCleanup()` so a Free user
    /// can't bypass the gate by calling the VM directly.
    var canCleanup: Bool {
        subscriptionController?.currentEntitlement.isPro ?? true
    }

    /// Cleanup gate. When a `SubscriptionController` is wired in,
    /// Pro is required to move any bytes. Free users get the paywall
    /// presented and a no-op `CleanupResult` (the caller never sees
    /// a "successful empty delete" — the bytes are unchanged on disk).
    ///
    /// When no controller is wired (legacy tests), the gate stays
    /// open so existing unit tests don't have to be updated.
    func gateCleanup() -> Bool {
        guard let controller = subscriptionController else { return true }
        return controller.requirePro(trigger: .gatedAction)
    }

    /// Gate for Pro file actions that are not cleanup, such as revealing
    /// scanned files in Finder. Scanning and read-only preview remain free.
    func gateFileAction() -> Bool {
        guard let controller = subscriptionController else { return true }
        return controller.requirePro(trigger: .gatedAction)
    }
}
