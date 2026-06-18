import SwiftUI

struct StorageOrbView: View {
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var rotation = 0.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.9),
                            AppTheme.cyan,
                            AppTheme.violet,
                            AppTheme.accent.opacity(0.9)
                        ],
                        center: .center
                    )
                )
                .blur(radius: 2)
                .rotationEffect(.degrees(rotation))

            Circle()
                .fill(.ultraThinMaterial)
                .padding(18)

            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                .padding(31)

            Image(systemName: "internaldrive.fill")
                .font(.system(size: 58, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        .shadow(color: AppTheme.accent.opacity(0.28), radius: 30, y: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
