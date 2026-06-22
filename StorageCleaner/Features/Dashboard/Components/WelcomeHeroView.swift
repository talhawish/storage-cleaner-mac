import SwiftUI

/// The pre-scan, "love at first sight" hero shown on the Overview's idle state.
///
/// Composed of an aurora background, a twinkling starfield, a central
/// glowing core, two counter-rotating aurora rings, and six orbital
/// developer-domain glyphs. All visual layers and entrance staggers are
/// driven by this view; the actual drawing is delegated to `WelcomeHeroVisual`
/// and `WelcomeHeroText` to keep this body under the SwiftLint ceiling.
///
/// All motion honors `accessibilityReduceMotion`: when the user has reduced
/// motion enabled, every loop collapses to its end-state with no repetition
/// and no entrance animation.
struct WelcomeHeroView: View {
    let startScan: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    // Entrance animation
    @State private var didAppear = false
    // Ambient aurora blobs
    @State private var blobPhaseA: Double = 0
    @State private var blobPhaseB: Double = 0
    @State private var blobPhaseC: Double = 0
    // Twinkling stars
    @State private var twinklePhase: Double = 0
    // Core float
    @State private var coreOffset: CGFloat = 0
    @State private var coreGlow = false
    // Aurora rings
    @State private var ringRotation = 0.0
    @State private var ringRotationReverse = 0.0
    // Orbital sweep
    @State private var orbitPhase: Double = 0
    @State private var orbitPhaseReverse: Double = 0
    // Pulse halo
    @State private var haloScale: CGFloat = 1.0

    private let orbiters: [Orbiter] = [
        Orbiter(symbol: "hammer.fill", color: AppTheme.accent, radius: 108, speed: 22, size: 44, startAngle: 0),
        Orbiter(symbol: "globe", color: AppTheme.cyan, radius: 130, speed: 30, size: 38, startAngle: 60),
        Orbiter(symbol: "shippingbox.fill", color: AppTheme.violet, radius: 108, speed: 26, size: 40, startAngle: 120),
        Orbiter(symbol: "apps.iphone", color: AppTheme.mint, radius: 130, speed: 34, size: 38, startAngle: 180),
        Orbiter(symbol: "sparkles", color: AppTheme.orange, radius: 108, speed: 28, size: 40, startAngle: 240),
        Orbiter(symbol: "video.fill", color: AppTheme.pink, radius: 130, speed: 32, size: 38, startAngle: 300)
    ]

    private let stars: [Star] = [
        Star(offsetX: -110, offsetY: -85, size: 2.0, twinkleSpeed: 2.4, twinkleOffset: 0.0),
        Star(offsetX: 120, offsetY: -60, size: 1.6, twinkleSpeed: 3.1, twinkleOffset: 0.4),
        Star(offsetX: -90, offsetY: 90, size: 2.4, twinkleSpeed: 2.0, twinkleOffset: 0.8),
        Star(offsetX: 100, offsetY: 95, size: 1.4, twinkleSpeed: 3.6, twinkleOffset: 1.2),
        Star(offsetX: -130, offsetY: -10, size: 1.2, twinkleSpeed: 2.8, twinkleOffset: 0.2),
        Star(offsetX: 135, offsetY: 20, size: 1.8, twinkleSpeed: 3.4, twinkleOffset: 0.6),
        Star(offsetX: 30, offsetY: -120, size: 1.5, twinkleSpeed: 2.6, twinkleOffset: 1.0),
        Star(offsetX: -25, offsetY: 125, size: 1.3, twinkleSpeed: 3.0, twinkleOffset: 1.4),
        Star(offsetX: 75, offsetY: -95, size: 1.0, twinkleSpeed: 3.8, twinkleOffset: 0.5),
        Star(offsetX: -70, offsetY: 100, size: 1.1, twinkleSpeed: 2.2, twinkleOffset: 0.9)
    ]

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.extraLarge) {
            WelcomeHeroText(
                startScan: startScan,
                didAppear: didAppear,
                coreGlow: coreGlow,
                reduceMotion: reduceMotion
            )

            Spacer(minLength: 8)

            WelcomeHeroVisual(
                orbiters: orbiters,
                stars: stars,
                didAppear: didAppear,
                blobPhaseA: blobPhaseA,
                blobPhaseB: blobPhaseB,
                blobPhaseC: blobPhaseC,
                twinklePhase: twinklePhase,
                coreOffset: coreOffset,
                coreGlow: coreGlow,
                ringRotation: ringRotation,
                ringRotationReverse: ringRotationReverse,
                orbitPhase: orbitPhase,
                orbitPhaseReverse: orbitPhaseReverse,
                haloScale: haloScale,
                reduceMotion: reduceMotion
            )
            .frame(width: 320, height: 320)
            .accessibilityHidden(true)
        }
        .padding(AppTheme.Spacing.huge)
        .background(WelcomeHeroBackground(
            didAppear: didAppear,
            blobPhaseA: blobPhaseA,
            blobPhaseB: blobPhaseB,
            blobPhaseC: blobPhaseC,
            reduceMotion: reduceMotion
        ))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.45),
                            AppTheme.cyan.opacity(0.20),
                            AppTheme.violet.opacity(0.40)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: AppTheme.accent.opacity(0.20), radius: 36, y: 18)
        .onAppear(perform: startAnimations)
    }

    // MARK: - Animation orchestration

    private func startAnimations() {
        if reduceMotion {
            // Collapse every loop to a single, finite end-state.
            didAppear = true
            coreGlow = true
            haloScale = 1.0
            coreOffset = 0
            return
        }

        // Stagger the entrance — eyebrow first, then headline, subtitle, CTA.
        withAnimation(.snappy(duration: 0.5).delay(0.05)) {
            didAppear = true
        }

        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
            blobPhaseA = .pi * 2
        }
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            blobPhaseB = .pi * 2
        }
        withAnimation(.linear(duration: 36).repeatForever(autoreverses: false)) {
            blobPhaseC = .pi * 2
        }

        withAnimation(.linear(duration: 4.8).repeatForever(autoreverses: false)) {
            twinklePhase = .pi * 2
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            haloScale = 1.08
        }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
            coreOffset = -4
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            coreGlow = true
        }

        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            ringRotationReverse = -360
        }

        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            orbitPhase = 360
        }
        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
            orbitPhaseReverse = 360
        }
    }
}
