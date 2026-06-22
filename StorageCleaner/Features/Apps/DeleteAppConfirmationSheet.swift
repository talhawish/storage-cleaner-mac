import SwiftUI

struct DeleteAppConfirmationSheet: View {
    let app: AppItem
    let onUninstall: () async throws -> Void
    let onCancel: () -> Void

    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Uninstall App",
            subtitle: "This removes the application bundle",
            iconSystemName: "xmark.bin.fill",
            trailing: .sizeBadge(value: StorageFormatting.bytes(app.sizeBytes), tint: AppTheme.rose),
            showsCloseButton: false,
            preferredHeight: 520,
            confirm: AppModalActionBar.Action(
                title: "Uninstall",
                systemImage: "xmark.bin.fill",
                isProminent: true,
                isDestructive: true,
                isDisabled: isDeleting,
                isDefault: true,
                action: {
                    isDeleting = true
                    errorMessage = nil
                    Task {
                        do {
                            try await onUninstall()
                            onCancel()
                        } catch {
                            errorMessage = Self.message(for: error)
                            isDeleting = false
                        }
                    }
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
                            Text(app.url.path)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
                text: "You can reinstall this app from the App Store or its original source. "
                    + "Related support files can be reviewed separately in System Junk."
            )

            if let errorMessage {
                AppModalBanner(
                    systemImage: "exclamationmark.triangle.fill",
                    tint: AppTheme.orange,
                    text: errorMessage
                )
            }
        }
    }

    private static func message(for error: Error) -> String {
        let description = (error as NSError).localizedDescription
        guard !description.isEmpty else {
            return "The app could not be uninstalled. Check permissions and try again."
        }
        return description
    }
}
