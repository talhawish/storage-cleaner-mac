import SwiftUI

struct PostScanPaywallCard: View {
    let reclaimableBytes: Int64
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var reclaimableGB: Double {
        max(1, Double(reclaimableBytes) / 1_000_000_000)
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            graphicTile
            content
            Spacer(minLength: 0)
            cta
            dismissButton
        }
        .padding(AppTheme.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(AppTheme.subtleSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.accent.opacity(isHovering ? 0.50 : 0.0), lineWidth: 1.2)
        }
        .contentShape(Rectangle())
        .scaleEffect(isHovering && !reduceMotion ? 1.005 : 1)
        .shadow(
            color: AppTheme.accent.opacity(isHovering ? 0.20 : 0.0),
            radius: isHovering ? 22 : 0,
            y: isHovering ? 10 : 0
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("post-scan-paywall-card")
        .accessibilityLabel("You can reclaim \(StorageFormatting.bytes(reclaimableBytes)). One tap to clean with Pro.")
        .accessibilityHint("Opens the subscription page to unlock cleanup")
        .accessibilityAddTraits(.isButton)
    }

    private var graphicTile: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.15))
                .frame(width: 76, height: 76)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 28, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("You can reclaim \(StorageFormatting.bytes(reclaimableBytes))")
                    .font(.title3.weight(.bold))
            }
            Text("One tap to clean — start your Pro trial.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
            benefitPills
        }
    }

    private var benefitPills: some View {
        HStack(spacing: 8) {
            BenefitPill(symbol: "lock.open.fill", text: "Free scan included", tint: AppTheme.mint)
            BenefitPill(symbol: "trash.fill", text: "Clean on tap", tint: AppTheme.accent)
            BenefitPill(symbol: "sparkles", text: "Pro features", tint: AppTheme.amber)
        }
        .padding(.top, 4)
    }

    private var cta: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 6) {
                Text("Start Pro")
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(0.30), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("post-scan-paywall-cta")
        .help("Unlock cleanup with Storage Cleaner Pro")
    }

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Dismiss")
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("post-scan-paywall-dismiss")
        .help("Dismiss this suggestion")
    }
}

private struct BenefitPill: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.13), in: Capsule())
        .overlay {
            Capsule().stroke(tint.opacity(0.25), lineWidth: 0.5)
        }
    }
}
