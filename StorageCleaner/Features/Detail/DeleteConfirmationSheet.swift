import SwiftUI

struct DeleteConfirmationSheet: View {
    enum Mode {
        case files
        case cliPrograms
        case runtimeVersions
    }

    private static var trashPrefix: String { UserHomeDirectory.path + "/.Trash/" }

    let selectedURLs: [URL]
    let totalBytes: Int64
    var mode: Mode = .files
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var confirmed = false

    private var allInTrash: Bool {
        mode == .files && !selectedURLs.isEmpty
            && selectedURLs.allSatisfy { $0.path.hasPrefix(Self.trashPrefix) }
    }

    private var hasTrashItems: Bool {
        mode == .files && selectedURLs.contains { $0.path.hasPrefix(Self.trashPrefix) }
    }

    private var hasUnsupportedCLIItems: Bool {
        mode == .cliPrograms && selectedURLs.contains { !CLIRemovalPreview.forURL($0).canRemove }
    }

    private var titleText: String {
        if mode == .cliPrograms {
            return "Remove \(selectedURLs.count) tool\(selectedURLs.count == 1 ? "" : "s")"
        }
        if mode == .runtimeVersions {
            return "Remove \(selectedURLs.count) runtime version\(selectedURLs.count == 1 ? "" : "s")"
        }
        if allInTrash {
            return "Delete \(selectedURLs.count) item\(selectedURLs.count == 1 ? "" : "s") permanently"
        }
        if hasTrashItems {
            return "Clean up \(selectedURLs.count) item\(selectedURLs.count == 1 ? "" : "s")"
        }
        return "Move \(selectedURLs.count) item\(selectedURLs.count == 1 ? "" : "s") to Trash"
    }

    private var confirmLabel: String {
        if mode == .cliPrograms { return "Remove Tools" }
        if mode == .runtimeVersions { return "Remove Versions" }
        if hasTrashItems && !allInTrash { return "Delete Trash Items & Move Others" }
        return allInTrash ? "Delete Permanently" : "Move to Trash"
    }

    private var confirmIcon: String {
        allInTrash ? "xmark.bin.fill" : "trash.fill"
    }

    var body: some View {
        ConfirmationModal(
            variant: .destructive,
            title: titleText,
            subtitle: subtitleText,
            trailing: .sizeBadge(value: StorageFormatting.bytes(totalBytes), tint: AppTheme.rose),
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: confirmLabel,
                systemImage: confirmIcon,
                isProminent: true,
                isDestructive: true,
                isDisabled: confirmed || hasUnsupportedCLIItems,
                isDefault: true,
                action: {
                    confirmed = true
                    onDelete()
                }
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel", action: onCancel),
            isProcessing: confirmed
        ) {
            if mode == .cliPrograms {
                AppModalBanner(
                    systemImage: "info.circle.fill",
                    tint: AppTheme.cyan,
                    text: hasUnsupportedCLIItems
                        ? "Some selected tools require manual removal. Deselect them to continue."
                        : "Review each action below. A folder moved to Trash includes all its contents. "
                            + "Settings and saved data stored elsewhere may remain."
                )
            }
            AppModalSection(
                title: "Selected items",
                subtitle: "Up to 50 are shown",
                systemImage: "doc.on.doc.fill",
                tint: AppTheme.rose
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(selectedURLs.prefix(50).enumerated()), id: \.element) { index, url in
                        fileRow(url)
                        if index < min(selectedURLs.count, 50) - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, 4)
                .cardSurface()

                if selectedURLs.count > 50 {
                    Text("… and \(selectedURLs.count - 50) more items")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var subtitleText: String {
        if mode == .cliPrograms {
            return "Review the removal method and exact path for every selected tool."
        }
        if mode == .runtimeVersions {
            return "Homebrew versions are uninstalled; other runtime versions move to the Trash."
        }
        if hasTrashItems && !allInTrash {
            return "Items already in the Trash will be permanently deleted. Other items will move to the Trash."
        }
        return allInTrash
            ? "These items are already in the Trash and will be permanently removed."
            : "Review the selected files before cleanup"
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconForURL(url))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor(url))
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(url.standardizedFileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(url.standardizedFileURL.path)
                if mode == .cliPrograms {
                    let preview = CLIRemovalPreview.forURL(url)
                    Text(preview.method)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(preview.canRemove ? AppTheme.cyan : AppTheme.orange)
                    Text(preview.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func iconForURL(_ url: URL) -> String {
        if url.hasDirectoryPath { return "folder.fill" }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm": return "film.fill"
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng": return "photo.fill"
        case "apk", "aab": return "app.badge.fill"
        case "dmg": return "opticaldisc.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "log", "crash": return "doc.text.fill"
        case "tmp", "temp": return "doc.badge.clock.fill"
        default: return "doc.fill"
        }
    }

    private func iconColor(_ url: URL) -> Color {
        if url.hasDirectoryPath { return AppTheme.accent }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm": return AppTheme.pink
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng": return AppTheme.rose
        case "apk", "aab": return AppTheme.orange
        case "dmg": return AppTheme.violet
        case "zip", "tar", "gz": return AppTheme.indigo
        default: return .secondary
        }
    }
}

struct CategoryInfoSheet: View {
    let finding: StorageFinding

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        AppModal(
            idealWidth: 540,
            minHeight: 460,
            idealHeight: 500,
            maxHeight: 620
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: finding.domain.symbolName,
                    iconTint: AppTheme.color(for: finding.domain),
                    title: finding.kind.title,
                    subtitle: finding.kind.summary,
                    trailing: nil,
                    showsCloseButton: true
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        AppModalSection(
                            title: "Overview",
                            systemImage: "info.circle.fill",
                            tint: AppTheme.color(for: finding.domain)
                        ) {
                            AppModalCard {
                                VStack(spacing: 0) {
                                    infoRow("Domain", finding.domain.title)
                                    Divider()
                                    infoRow("Total Size", StorageFormatting.bytes(finding.bytes))
                                    Divider()
                                    infoRow("Items", "\(finding.itemCount)")
                                    Divider()
                                    infoRow("Safety", finding.safety.title)
                                    if !finding.examples.isEmpty {
                                        Divider()
                                        infoRow("Includes", finding.examples.joined(separator: ", "))
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: AppTheme.accent,
                            isDefault: true,
                            action: { dismiss() }
                        )
                    ],
                    style: .compact
                )
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
