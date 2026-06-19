import SwiftUI

/// A single Overview tip rendered as a small actionable card. Informational tips with no action are
/// shown without a chevron and are not interactive.
struct OverviewTipCard: View {
    let tip: OverviewTip
    let onAction: (OverviewTip) -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button {
            onAction(tip)
        } label: {
            HStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: tip.icon)
                    .font(.system(size: AppTheme.IconSize.sub, weight: .semibold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 38, height: 38)
                    .background(tip.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tip.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(tip.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if tip.action != nil {
                    Spacer(minLength: AppTheme.Spacing.small)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(AppTheme.Spacing.mediumLarge)
            .frame(width: 320, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(tip.action == nil)
        .cardSurface()
        .scaleEffect(isHovering && tip.action != nil && !reduceMotion ? 1.02 : 1)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tip.title). \(tip.message)")
    }
}
