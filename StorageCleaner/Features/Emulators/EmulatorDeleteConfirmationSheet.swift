import SwiftUI

/// Confirmation for removing emulator/simulator OS images. Unlike the
/// generic delete sheet, this is explicit about what each removal does:
/// Apple runtimes are *uninstalled* (re-downloadable from Apple), while
/// Android images are *moved to the Trash* (restorable).
struct EmulatorDeleteConfirmationSheet: View {
    let images: [EmulatorImage]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmed = false

    private var totalBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }
    private var hasUninstall: Bool {
        images.contains { if case .simctlRuntime = $0.removal { true } else { false } }
    }
    private var hasTrash: Bool { images.contains { $0.removal.isReversible } }

    var body: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Remove \(images.count) OS image\(images.count == 1 ? "" : "s")",
            subtitle: "Reclaims \(StorageFormatting.bytes(totalBytes))",
            iconSystemName: "externaldrive.badge.minus",
            trailing: .sizeBadge(value: StorageFormatting.bytes(totalBytes), tint: AppTheme.orange),
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: "Remove \(images.count)",
                systemImage: "externaldrive.badge.minus",
                isProminent: true,
                isDestructive: true,
                isDisabled: confirmed,
                isDefault: true,
                action: {
                    confirmed = true
                    onConfirm()
                }
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel", action: onCancel),
            isProcessing: confirmed
        ) {
            if hasUninstall || hasTrash {
                AppModalSection(
                    title: "What will happen",
                    systemImage: "info.circle.fill",
                    tint: AppTheme.cyan
                ) {
                    VStack(spacing: AppTheme.Spacing.small) {
                        if hasUninstall {
                            AppModalBanner(
                                systemImage: "arrow.down.circle",
                                tint: AppTheme.accent,
                                text: "Apple simulator runtimes are uninstalled. They can't be "
                                    + "recovered from the Trash, but you can re-download them "
                                    + "anytime from Xcode."
                            )
                        }
                        if hasTrash {
                            AppModalBanner(
                                systemImage: "trash",
                                tint: AppTheme.mint,
                                text: "Android system images are moved to the Trash, so you can "
                                    + "restore them until you empty it."
                            )
                        }
                    }
                }
            }

            AppModalSection(
                title: "Selected images",
                systemImage: "list.bullet",
                tint: AppTheme.orange
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        imageRow(image)
                        if index < images.count - 1 {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .cardSurface()
            }
        }
    }

    private func imageRow(_ image: EmulatorImage) -> some View {
        HStack(spacing: 10) {
            Image(systemName: image.platform.symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.color(for: image.platform.accentColor))
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(image.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(image.removal.effectDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(StorageFormatting.bytes(image.bytes))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
