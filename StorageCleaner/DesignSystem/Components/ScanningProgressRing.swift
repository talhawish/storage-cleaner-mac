import SwiftUI

/// The multi-layer animated progress ring at the centre of
/// `ScanningLoaderView`. Renders a determinate percentage or an indeterminate
/// spinner, with a soft pulsing glow, a gradient arc, and a slowly rotating
/// ambient ring for depth. All motion respects `accessibilityReduceMotion`.
struct ScanningProgressRing: View {
    let progress: Double?
    let tint: Color
    let isPreparing: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var spinnerRotation: Double = 0
    @State private var ambientRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.30
    @State private var iconPulse: CGFloat = 1.0

    private let diameter: CGFloat = 180
    private let lineWidth: CGFloat = 10

    init(progress: Double?, tint: Color) {
        self.progress = progress
        self.tint = tint
        self.isPreparing = progress == nil || progress == 0
    }

    var body: some View {
        ZStack {
            glowLayer
            trackRing
            progressLayer
            ambientRing
            centerContent
        }
        .frame(width: diameter, height: diameter)
        .onAppear { startAnimations() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan progress")
        .accessibilityValue(accessibilityValue)
    }

    // MARK: - Layers

    /// Soft pulsing glow behind the ring — gives the indicator depth and life.
    private var glowLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [tint.opacity(glowOpacity), tint.opacity(0)],
                    center: .center,
                    startRadius: diameter * 0.28,
                    endRadius: diameter * 0.52
                )
            )
            .scaleEffect(glowScale)
            .blur(radius: 6)
    }

    /// The subtle full-circle track the progress arc fills on top of.
    private var trackRing: some View {
        Circle()
            .stroke(.quaternary, lineWidth: lineWidth)
    }

    @ViewBuilder private var progressLayer: some View {
        if let progress, !isPreparing {
            determinateArc(progress)
        } else {
            indeterminateArc
        }
    }

    private func determinateArc(_ progress: Double) -> some View {
        Circle()
            .trim(from: 0, to: max(0.001, min(progress, 1)))
            .stroke(
                AngularGradient(
                    colors: [tint, AppTheme.cyan, tint],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: tint.opacity(0.45), radius: 6)
            .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: progress)
    }

    private var indeterminateArc: some View {
        Circle()
            .trim(from: 0, to: 0.22)
            .stroke(
                AngularGradient(
                    colors: [tint, tint.opacity(0.0)],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(spinnerRotation - 90))
            .shadow(color: tint.opacity(0.35), radius: 5)
    }

    /// A faint decorative ring just outside the main ring, rotating very slowly
    /// for ambient depth without pulling focus.
    private var ambientRing: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [tint.opacity(0), tint.opacity(0.15), tint.opacity(0)],
                    center: .center
                ),
                lineWidth: 1
            )
            .frame(width: diameter + 16, height: diameter + 16)
            .rotationEffect(.degrees(ambientRotation))
    }

    @ViewBuilder private var centerContent: some View {
        if isPreparing {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .scaleEffect(iconPulse)
                .accessibilityHidden(true)
        } else {
            VStack(spacing: 2) {
                Text(progress ?? 0, format: .percent.precision(.fractionLength(0)))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)
                Text("complete")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Animation

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            spinnerRotation = 360
        }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ambientRotation = 360
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            glowScale = 1.06
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            glowOpacity = 0.50
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            iconPulse = 1.08
        }
    }

    private var accessibilityValue: String {
        if let progress {
            return progress.formatted(.percent.precision(.fractionLength(0)))
        }
        return "Preparing"
    }
}
