import SwiftUI

struct DockerActionConfirmationSheet: View {
    let action: PendingDockerAction
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmed = false

    var body: some View {
        ConfirmationModal(
            variant: action.isIrreversible ? .destructive : .neutral,
            title: action.title,
            subtitle: action.itemName,
            iconSystemName: action.isCleanup ? "shippingbox.and.arrow.backward.fill" : "stop.circle.fill",
            trailing: action.estimatedBytes > 0
                ? .sizeBadge(
                    value: "Up to \(StorageFormatting.bytes(action.estimatedBytes))",
                    tint: AppTheme.orange
                )
                : nil,
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: action.confirmTitle,
                systemImage: action.isCleanup ? "trash" : "stop.fill",
                isProminent: true,
                isDestructive: action.isIrreversible,
                isDisabled: confirmed,
                isDefault: true,
                action: confirm
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel", action: onCancel),
            isProcessing: confirmed
        ) {
            AppModalSection(
                title: "What will happen",
                systemImage: "info.circle.fill",
                tint: action.isIrreversible ? AppTheme.orange : AppTheme.cyan
            ) {
                AppModalBanner(
                    systemImage: action.isIrreversible ? "exclamationmark.triangle.fill" : "info.circle.fill",
                    tint: action.isIrreversible ? AppTheme.orange : AppTheme.cyan,
                    text: action.explanation
                )
            }

            if action.isCleanup {
                AppModalSection(
                    title: "Recovery estimate",
                    systemImage: "internaldrive",
                    tint: AppTheme.mint
                ) {
                    LabeledContent("Estimated space") {
                        Text(recoveryEstimate)
                            .monospacedDigit()
                    }
                    .padding(14)
                    .cardSurface()
                }
            }
        }
    }

    private var recoveryEstimate: String {
        guard action.estimatedBytes > 0 else { return "Docker will report after removal" }
        return "Up to \(StorageFormatting.bytes(action.estimatedBytes))"
    }

    private func confirm() {
        confirmed = true
        onConfirm()
    }
}
