import SwiftUI

/// App-wide sheet shown when a cleanup couldn't move every selected item to
/// Trash. Presented by `AppShellView` from `DashboardViewModel.cleanupFailure`
/// so Large Files, Leftovers, Duplicates, Developer Storage, CLI and runtime
/// removals all report failures the same way. "Retry" routes the failed items
/// back through the operation that produced them.
struct CleanupFailureSheet: View {
    let prompt: CleanupFailurePrompt
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ConfirmationModal(
            variant: .warning,
            title: prompt.feedback.title,
            message: prompt.feedback.message,
            showsCloseButton: false,
            preferredHeight: 300,
            confirm: AppModalActionBar.Action(
                title: prompt.feedback.confirmTitle,
                systemImage: "arrow.clockwise",
                isProminent: true,
                isDefault: true,
                help: "Try moving the failed items to the Trash again",
                action: onRetry
            ),
            cancel: AppModalActionBar.CancelAction(
                title: prompt.feedback.cancelTitle,
                action: onDismiss
            )
        )
        .accessibilityIdentifier("cleanup-failure-sheet")
    }
}
