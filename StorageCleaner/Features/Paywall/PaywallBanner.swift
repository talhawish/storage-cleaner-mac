import SwiftUI

/// Short status feedback shown above the subscription plan row.
struct PaywallBanner: View {
    let tint: Color
    let systemImage: String
    let text: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.bold())
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: AppTheme.Radius.small))
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(reduceMotion ? nil : .smooth, value: text)
    }
}
