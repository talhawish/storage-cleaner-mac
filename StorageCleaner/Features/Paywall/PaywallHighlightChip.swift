import SwiftUI

/// One short value proposition in the paywall hero's wrapping feature list.
struct PaywallHighlightChip: View {
    let highlight: PaywallHero.Highlight

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: highlight.icon)
                .font(.caption.bold())
                .accessibilityHidden(true)
            Text(highlight.title)
                .font(.caption)
                .bold()
        }
        .foregroundStyle(highlight.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(highlight.tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(highlight.tint.opacity(0.25), lineWidth: 0.5)
        }
    }
}
