import SwiftUI

/// A single installed version inside a `RuntimeVersionGroupCard`.
///
/// Three presentations: the newest version is locked as "Keep · latest", versions that require
/// manual removal (system JDKs) show a lock affordance, and every other older version is a
/// selectable removal candidate.
struct RuntimeVersionRow: View {
    let item: RuntimeVersionItem
    let runtime: DevRuntime
    let requiresManualRemoval: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            leadingControl

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.versionLabel)
                        .font(.body.weight(.medium).monospacedDigit())
                        .lineLimit(1)
                    if item.isNewest {
                        Text("Keep · latest")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(AppTheme.mint.opacity(0.16), in: Capsule())
                            .foregroundStyle(AppTheme.mint)
                    }
                }

                Text(StoragePathFormatting.abbreviatingHome(item.url))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            sizeLabel
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovering && isSelectable ? Color.accentColor.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var isSelectable: Bool { !item.isNewest && !requiresManualRemoval }

    @ViewBuilder private var leadingControl: some View {
        if item.isNewest {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.mint)
                .font(.system(size: 16))
                .frame(width: 18)
                .accessibilityHidden(true)
        } else if requiresManualRemoval {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .frame(width: 18)
                .help("System JDKs are managed by macOS and must be removed manually.")
                .accessibilityHidden(true)
        } else {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Select \(runtime.title) \(item.versionLabel)")
        }
    }

    @ViewBuilder private var sizeLabel: some View {
        if item.bytes > 0 {
            Text(StorageFormatting.bytes(item.bytes))
                .font(.callout.monospacedDigit().weight(.medium))
                .contentTransition(.numericText())
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44)
        }
    }

    private var accessibilityDescription: String {
        var parts = ["\(runtime.title) \(item.versionLabel)"]
        if item.isNewest {
            parts.append("latest, kept")
        } else if requiresManualRemoval {
            parts.append("requires manual removal")
        }
        if item.bytes > 0 { parts.append(StorageFormatting.bytes(item.bytes)) }
        return parts.joined(separator: ", ")
    }
}
