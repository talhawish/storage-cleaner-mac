import SwiftUI

/// Wide, full-width card dedicated to the one-tap Quick Clean action.
/// Shown below the hero on the Overview's idle state. Has a tinted
/// graphic on the left, a title + subtitle + two benefit pills in the
/// middle, and a prominent solid-color CTA on the right.
struct QuickCleanEntry: View {
    let action: () -> Void

    @State private var isHovering = false
    @State private var sparkleScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.large) {
                graphicTile
                content
                Spacer(minLength: 0)
                cta
            }
            .padding(AppTheme.Spacing.large)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.accent.opacity(isHovering ? 0.50 : 0.0), lineWidth: 1.2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && !reduceMotion ? 1.005 : 1)
        .shadow(
            color: AppTheme.accent.opacity(isHovering ? 0.20 : 0.0),
            radius: isHovering ? 22 : 0,
            y: isHovering ? 10 : 0
        )
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear { startAnimations() }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quick-clean-card")
        .accessibilityLabel("Quick Clean. Instantly find and trash safe-to-delete files.")
        .accessibilityHint("Opens Quick Clean to scan and remove safe files in one tap")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Graphic tile

    /// Decorative graphic on the left: a tinted disc with a "bolt" glyph
    /// in the middle. The disc gently pulses to signal an instant action.
    private var graphicTile: some View {
        ZStack {
            Circle()
                .fill(AppTheme.accent.opacity(0.15))
                .frame(width: 76, height: 76)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }
                .scaleEffect(reduceMotion ? 1.0 : sparkleScale)

            Image(systemName: "bolt.fill")
                .font(.system(size: 28, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Quick Clean")
                    .font(.title3.weight(.bold))
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
            Text("Instantly find and trash safe-to-delete files across your developer tools and system caches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
            benefitPills
        }
    }

    private var benefitPills: some View {
        HStack(spacing: 8) {
            BenefitPill(symbol: "checkmark.shield.fill", text: "Auto-safe", tint: AppTheme.mint)
            BenefitPill(symbol: "bolt.fill", text: "1-tap", tint: AppTheme.amber)
        }
        .padding(.top, 4)
    }

    // MARK: - CTA

    private var cta: some View {
        HStack(spacing: 6) {
            Text("Start Quick Clean")
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

    // MARK: - Animations

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            sparkleScale = 1.06
        }
    }
}

// MARK: - Benefit pill

/// Small rounded chip used in the Quick Clean card to highlight a single
/// trust attribute. Renders as a small tinted icon + label.
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
