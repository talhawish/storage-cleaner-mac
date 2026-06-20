import SwiftUI

struct DeleteAppConfirmationSheet: View {
    let app: AppItem
    let onDelete: () async -> Void
    let onCancel: () -> Void

    @State private var isDeleting = false

    var body: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Move to Trash",
            subtitle: "This app will be moved to Trash",
            trailing: .sizeBadge(value: StorageFormatting.bytes(app.sizeBytes), tint: AppTheme.rose),
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: "Move to Trash",
                systemImage: "trash.fill",
                isProminent: true,
                isDestructive: true,
                isDisabled: isDeleting,
                isDefault: true,
                action: {
                    isDeleting = true
                    Task { await onDelete() }
                }
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel", action: onCancel),
            isProcessing: isDeleting
        ) {
            AppModalSection(
                title: "Application",
                systemImage: "app.fill",
                tint: AppTheme.rose
            ) {
                AppModalCard {
                    HStack(spacing: 14) {
                        if let icon = NSWorkspace.shared.icon(forFile: app.url.path) as NSImage? {
                            Image(nsImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.displayName)
                                .font(.headline)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                }
            }

            AppModalBanner(
                systemImage: "info.circle.fill",
                tint: AppTheme.cyan,
                text: "You can reinstall this app from the App Store or its original source at any time."
            )
        }
    }
}
