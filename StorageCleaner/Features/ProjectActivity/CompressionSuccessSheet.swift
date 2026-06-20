import SwiftUI

/// Modal shown after a successful "Hibernate & Compress" — reports where the
/// zip archive was written and how much space was reclaimed. Built on
/// `AppModal` so the layout matches the rest of the app's detail sheets.
struct CompressionSuccessSheet: View {
    let outcome: CompressionOutcome

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        AppModal(idealWidth: 540, minHeight: 380, idealHeight: 420) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: "checkmark.seal.fill",
                    iconTint: AppTheme.mint,
                    title: "Project Archived",
                    subtitle: "Reclaimed \(StorageFormatting.bytes(outcome.totalReclaimedBytes))",
                    trailing: nil,
                    showsCloseButton: true
                )

                Divider()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.mediumLarge) {
                        AppModalCard {
                            VStack(alignment: .leading, spacing: 10) {
                                detailRow(
                                    label: "Archive",
                                    value: outcome.zipURL.lastPathComponent,
                                    monospaced: true
                                )
                                detailRow(
                                    label: "Location",
                                    value: outcome.zipURL.deletingLastPathComponent().path,
                                    monospaced: true
                                )
                                Divider()
                                detailRow(label: "Original size", value: StorageFormatting.bytes(outcome.originalSize))
                                detailRow(label: "Archive size", value: StorageFormatting.bytes(outcome.archiveSize))
                                detailRow(
                                    label: "Dependencies reclaimed",
                                    value: StorageFormatting.bytes(outcome.reclaimedDependencyBytes)
                                )
                            }
                        }

                        AppModalBanner(
                            systemImage: "trash",
                            tint: AppTheme.mint,
                            text: "The original folder is in the Trash. "
                                + "Rebuild dependencies with a single install command."
                        )
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Show in Finder",
                            systemImage: "folder",
                            tint: AppTheme.accent,
                            isDefault: true,
                            action: {
                                NSWorkspace.shared.activateFileViewerSelecting([outcome.zipURL])
                                dismiss()
                            }
                        )
                    ],
                    style: .compact
                )
            }
        }
    }

    private func detailRow(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
                .textCase(.uppercase)
            Text(value)
                .font(monospaced ? .caption.monospaced() : .caption)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer()
        }
    }
}
