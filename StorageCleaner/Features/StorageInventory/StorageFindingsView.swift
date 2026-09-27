import SwiftUI

/// A compact inventory list for findings that always require a human decision.
/// Selecting a row opens the shared path browser and Trash-confirmation flow.
struct StorageFindingsView: View {
    let title: String
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onOpenFinding: (StorageFinding) -> Void

    @State private var inventory = StorageInventoryPresentation()

    var body: some View {
        List {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Review before removing")
                            .font(.headline)
                        Text(inventory.reviewMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(AppTheme.orange)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("storage-review-notice")
            }

            Section {
                ForEach(inventory.items) { item in
                    Button {
                        onOpenFinding(item.detailFinding)
                    } label: {
                        StorageFindingPathRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.accessibilityLabel)
                    .accessibilityHint(
                        "Opens the full paths and contents. Selected items can be moved to the Trash "
                            + "after confirmation."
                    )
                }
            } header: {
                SectionHeader(
                    title: title,
                    subtitle: inventory.summary,
                    systemImage: "externaldrive.fill"
                )
            }
        }
        .task(id: findings) {
            let findings = findings
            let updated = await Task.detached(priority: .userInitiated) {
                StorageInventoryPresentation(findings: findings)
            }.value
            guard !Task.isCancelled else { return }
            inventory = updated
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .navigationTitle(title)
        .navigationSubtitle("\(inventory.summary) · Review first")
        .accessibilityIdentifier("storage-findings-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .toolbar {
            ToolbarItem {
                Button(action: onScan) {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Rescan these storage locations")
            }
        }
    }
}

private struct StorageFindingPathRow: View {
    let item: ReviewableStorageItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.color(for: item.finding.domain))
                .frame(width: 32, height: 32)
                .background(
                    AppTheme.color(for: item.finding.domain).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Review first")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.orange)
                        .lineLimit(1)
                }

                Text(item.url.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)

                Text(item.finding.kind.title)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(StorageFormatting.bytes(item.bytes))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private var symbolName: String {
        item.finding.kind == .largeFolders ? "folder.fill" : item.finding.domain.symbolName
    }
}
