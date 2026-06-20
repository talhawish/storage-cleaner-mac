import SwiftUI

/// A circular progress ring used during the scanning phase. Pure presentation;
/// the parent passes the current fraction (0...1) and total count.
struct QuickCleanProgressRing: View {
    let fraction: Double
    let isIndeterminate: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var rotation: Double = 0

    private var clampedFraction: Double { max(0, min(1, fraction)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)
                .frame(width: 96, height: 96)

            if isIndeterminate {
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent, AppTheme.cyan, AppTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
            } else {
                Circle()
                    .trim(from: 0, to: clampedFraction)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent, AppTheme.cyan, AppTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: clampedFraction)
                    .frame(width: 96, height: 96)
            }

            Text(isIndeterminate ? "…" : "\(Int(clampedFraction * 100))%")
                .font(.title2.bold().monospacedDigit())
                .contentTransition(.numericText())
        }
        .accessibilityHidden(true)
    }
}
