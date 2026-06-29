import SwiftUI
import AppKit

/// The correct "preview" for a CLI program: a details panel with file-system
/// actions, replacing the media image preview that CLI Programs used to show.
struct CLIProgramDetailSheet: View {
    let program: CLIProgram
    let size: Int64?
    var canRevealInFinder = true

    @Environment(\.dismiss)
    private var dismiss
    @State private var exists = true

    var body: some View {
        AppModal(
            idealWidth: 560,
            minHeight: 460,
            idealHeight: 540,
            maxHeight: 660
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: program.symbolName,
                    iconTint: program.accent,
                    title: program.displayName,
                    subtitle: program.category.title,
                    trailing: .statusBadge(
                        text: program.safety.title,
                        tint: program.safety == .safe ? AppTheme.mint : AppTheme.orange
                    ),
                    showsCloseButton: false
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        AppModalSection(
                            title: "What this is",
                            systemImage: "text.alignleft",
                            tint: AppTheme.accent
                        ) {
                            AppModalCard {
                                Text(program.subtitle)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        AppModalSection(
                            title: "Details",
                            systemImage: "info.circle.fill",
                            tint: AppTheme.cyan
                        ) {
                            AppModalCard {
                                VStack(spacing: 0) {
                                    detailRow("Size", value: size.map(StorageFormatting.bytes) ?? "Calculating…")
                                    Divider()
                                    detailRow(
                                        "Location",
                                        value: StoragePathFormatting.abbreviatingHome(program.url),
                                        monospaced: true
                                    )
                                    Divider()
                                    detailRow("Status", value: exists ? "Present on disk" : "Missing")
                                }
                            }
                        }

                        AppModalBanner(
                            systemImage: program.safety == .safe ? "checkmark.shield.fill" : "eye.fill",
                            tint: program.safety == .safe ? AppTheme.mint : AppTheme.orange,
                            text: safetyMessage
                        )
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Reveal in Finder",
                            systemImage: "folder",
                            tint: AppTheme.accent,
                            isDisabled: !exists || !canRevealInFinder,
                            action: {
                                NSWorkspace.shared.activateFileViewerSelecting([program.url])
                            }
                        )
                    ],
                    style: .compact
                )
            }
        }
        .task { exists = FileManager.default.fileExists(atPath: program.url.path) }
    }

    private func detailRow(_ label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(monospaced ? .subheadline.monospaced() : .subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var safetyMessage: String {
        switch program.safety {
        case .safe:
            "This is a re-downloadable cache. Removing it is safe — tools will rebuild it on next use."
        case .review:
            "Removing this uninstalls toolchains or versions. Review before deleting; you may need to reinstall."
        }
    }
}
