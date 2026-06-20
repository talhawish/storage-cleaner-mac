import SwiftUI

/// A circular hero badge used by idle, scanning, and success states across
/// the app. The tint is applied to the background at 12% and to the SF Symbol
/// at full strength. The symbol size is parameterised so the same component
/// works for both the larger idle/success badges and the smaller scanning
/// indicator.
struct HeroBadge: View {
    let systemImage: String
    let tint: Color
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }
}
