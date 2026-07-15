import SwiftUI

/// Card-shaped loading placeholder that mirrors the final plan layout.
struct PlanCardSkeleton: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            placeholder(width: 60, height: 12)
            placeholder(width: 90, height: 26)
            placeholder(width: 60, height: 12)
            Spacer(minLength: 0)
            placeholder(height: 30)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(AppTheme.surface, in: .rect(cornerRadius: AppTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityLabel("Loading subscription plan")
        .onAppear(perform: startAnimation)
    }

    private func placeholder(width: CGFloat? = nil, height: CGFloat) -> some View {
        Capsule()
            .fill(gradient)
            .frame(width: width, height: height)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.subtleSurface,
                AppTheme.subtleSurface.opacity(0.7),
                AppTheme.subtleSurface
            ],
            startPoint: UnitPoint(x: reduceMotion ? 0 : phase - 1, y: 0.5),
            endPoint: UnitPoint(x: reduceMotion ? 1 : phase, y: 0.5)
        )
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            phase = 2
        }
    }
}
