import SwiftUI

/// Compact row for a single detection finding in the Overview's grouped list. Replaces the large
/// `StorageCategoryCard` so the per-kind detail stays dense and scannable.
struct DetectionRow: View {
    let finding: StorageFinding
    let onSelect: () -> Void
    @State private var isHovering = false

    private var tint: Color { AppTheme.color(for: finding.domain) }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: finding.domain.symbolName)
                    .font(.system(size: AppTheme.IconSize.body, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(finding.kind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AppTheme.Spacing.medium)

                StatusBadge(safety: finding.safety)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(StorageFormatting.bytes(finding.bytes))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Text("\(StorageFormatting.items(finding.itemCount)) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 72, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppTheme.Spacing.mediumLarge)
            .padding(.vertical, AppTheme.Spacing.medium)
            .contentShape(Rectangle())
            .background(isHovering ? tint.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(finding.kind.title), \(finding.domain.title), \(StorageFormatting.bytes(finding.bytes)), "
                + "\(StorageFormatting.items(finding.itemCount)) items, \(finding.safety.title)"
        )
        .accessibilityHint("Opens the category details")
        .accessibilityAddTraits(.isButton)
    }
}
