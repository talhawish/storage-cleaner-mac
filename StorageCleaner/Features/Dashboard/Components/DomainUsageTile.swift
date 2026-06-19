import SwiftUI

/// Compact tile in the Overview breakdown grid: one rolled-up storage domain with its size, share of
/// the total, and a thin share bar. Activating it scrolls the detection list to the matching group.
struct DomainUsageTile: View {
    let usage: StorageOverview.DomainUsage
    let onSelect: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var tint: Color { AppTheme.color(for: usage.domain) }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: usage.domain.symbolName)
                        .font(.system(size: AppTheme.IconSize.body, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .accessibilityHidden(true)

                    Spacer()

                    Text(usage.shareLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(StorageFormatting.bytes(usage.bytes))
                        .font(.title3.weight(.bold))
                        .contentTransition(.numericText())
                }

                ShareBar(fraction: usage.share, tint: tint)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .scaleEffect(isHovering && !reduceMotion ? 1.02 : 1)
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0.03), radius: isHovering ? 12 : 4, y: 4)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(usage.displayTitle), \(StorageFormatting.bytes(usage.bytes)), \(usage.shareLabel) of total"
        )
        .accessibilityHint("Shows this group in the list below")
        .accessibilityAddTraits(.isButton)
    }
}

/// Thin proportional bar showing a domain's share of total reclaimable space.
private struct ShareBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.13))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
