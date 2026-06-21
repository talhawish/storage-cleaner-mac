import SwiftUI

/// Confirmation sheet shown when the user tries to switch sidebar tabs
/// while a scan is running. Lets the user either stop the scan and switch,
/// or stay on the current section and let the scan finish.
struct StopScanConfirmationSheet: View {
    let originSection: String
    let destinationSection: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Stop the scan in progress?",
            message: "A scan is running on \(originSection). Switching to \(destinationSection) "
                + "will stop the scan and discard its results so far.",
            iconSystemName: "stop.circle.fill",
            showsCloseButton: true,
            confirm: AppModalActionBar.Action(
                title: "Stop & Switch",
                systemImage: "arrow.triangle.branch",
                isProminent: true,
                isDestructive: true,
                isDefault: true,
                action: onConfirm
            ),
            cancel: AppModalActionBar.CancelAction(
                title: "Keep Scanning",
                action: onCancel
            )
        )
        .accessibilityIdentifier("stop-scan-confirmation")
    }
}
