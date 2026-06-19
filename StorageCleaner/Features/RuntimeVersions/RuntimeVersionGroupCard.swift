import SwiftUI

/// One card per runtime+manager with multiple installed versions. Shows the runtime identity,
/// the manager it came from, the reclaimable total, and the individual version rows.
struct RuntimeVersionGroupCard: View {
    let group: RuntimeVersionGroup
    let selectedURLs: Set<URL>
    let onToggle: (URL) -> Void
    let onToggleAllOlder: () -> Void

    private var accent: Color { AppTheme.color(for: group.runtime.accentColor) }

    private var olderURLs: [URL] { group.olderItems.map(\.url) }

    private var allOlderSelected: Bool {
        !group.source.requiresManualRemoval
            && !olderURLs.isEmpty
            && olderURLs.allSatisfy(selectedURLs.contains)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                ForEach(group.items) { item in
                    RuntimeVersionRow(
                        item: item,
                        runtime: group.runtime,
                        requiresManualRemoval: group.source.requiresManualRemoval,
                        isSelected: selectedURLs.contains(item.url),
                        onToggle: { onToggle(item.url) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            if group.source.requiresManualRemoval {
                manualRemovalNote
            }
        }
        .padding(.vertical, 4)
        .cardSurface()
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: group.runtime.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.runtime.title)
                    .font(.headline)
                Text("\(group.items.count) versions · \(group.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(StorageFormatting.bytes(group.reclaimableBytes))
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(group.reclaimableBytes > 0 ? .primary : .secondary)
                Text("reclaimable")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !group.source.requiresManualRemoval, !olderURLs.isEmpty {
                Button(action: onToggleAllOlder) {
                    Text(allOlderSelected ? "Deselect older" : "Select older")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
    }

    private var manualRemovalNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("System JDKs live in /Library/Java and are managed by macOS — remove them manually "
                + "or with your JDK installer.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}
