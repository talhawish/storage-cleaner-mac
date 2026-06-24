import SwiftUI

/// The animated centerpiece of `PermissionRequiredView`.
///
/// A central folder glyph with a small lock badge floats gently while six
/// developer-domain orbiters (Desktop, Documents, Downloads, Movies, Pictures,
/// Library) revolve around it on two counter-rotating rings. A soft pulsing
/// halo, a slow gradient ring, and a drifting aurora background give the
/// scene ambient life. All motion honors `accessibilityReduceMotion`; when
/// reduced motion is enabled the loops collapse to their end states.
struct PermissionRequiredHero: View {
    let reduceMotion: Bool

    // MARK: - Animation state

    @State private var ringRotation: Double = 0
    @State private var ringRotationReverse: Double = 0
    @State private var haloScale: CGFloat = 1.0
    @State private var coreOffset: CGFloat = 0
    @State private var coreGlow: Bool = false
    @State private var lockBob: CGFloat = 0
    @State private var orbitPhase: Double = 0
    @State private var orbitPhaseReverse: Double = 0
    @State private var blobPhaseA: Double = 0
    @State private var blobPhaseB: Double = 0

    // MARK: - Layout constants

    private let orbiters: [HeroOrbiter] = [
        HeroOrbiter(
            symbol: "desktopcomputer",
            color: AppTheme.accent,
            radius: 96,
            speed: 22,
            size: 36,
            startAngle: 0
        ),
        HeroOrbiter(
            symbol: "doc.fill",
            color: AppTheme.cyan,
            radius: 118,
            speed: 30,
            size: 32,
            startAngle: 60
        ),
        HeroOrbiter(
            symbol: "arrow.down.circle.fill",
            color: AppTheme.violet,
            radius: 96,
            speed: 26,
            size: 32,
            startAngle: 120
        ),
        HeroOrbiter(
            symbol: "film.fill",
            color: AppTheme.pink,
            radius: 118,
            speed: 34,
            size: 32,
            startAngle: 180
        ),
        HeroOrbiter(
            symbol: "photo.fill",
            color: AppTheme.orange,
            radius: 96,
            speed: 28,
            size: 32,
            startAngle: 240
        ),
        HeroOrbiter(
            symbol: "books.vertical.fill",
            color: AppTheme.indigo,
            radius: 118,
            speed: 32,
            size: 32,
            startAngle: 300
        )
    ]

    var body: some View {
        ZStack {
            backgroundLayer
            haloLayer
            ringLayer
            orbitLayer
            coreLayer
        }
        .frame(width: 240, height: 240)
        .onAppear(perform: startAnimations)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.appBackground.opacity(0.001)

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.30))
                    .frame(width: 200, height: 200)
                    .blur(radius: 70)
                    .offset(
                        x: cos(blobPhaseA) * 40,
                        y: sin(blobPhaseA * 0.8) * 24
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.28))
                    .frame(width: 180, height: 180)
                    .blur(radius: 70)
                    .offset(
                        x: cos(blobPhaseB * 0.9 + 1.5) * 36,
                        y: sin(blobPhaseB) * 28
                    )
            }
        }
    }

    // MARK: - Halo

    private var haloLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        AppTheme.accent.opacity(reduceMotion ? 0.18 : (haloScale > 1.0 ? 0.24 : 0.16)),
                        AppTheme.accent.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 36,
                    endRadius: 120
                )
            )
            .scaleEffect(reduceMotion ? 1.0 : haloScale)
    }

    // MARK: - Rings

    private var ringLayer: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.0),
                            AppTheme.accent.opacity(0.55),
                            AppTheme.cyan.opacity(0.45),
                            AppTheme.violet.opacity(0.45),
                            AppTheme.accent.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.4
                )
                .frame(width: 184, height: 184)
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
                .blur(radius: 0.4)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.violet.opacity(0.0),
                            AppTheme.violet.opacity(0.45),
                            AppTheme.pink.opacity(0.35),
                            AppTheme.accent.opacity(0.35),
                            AppTheme.violet.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.0
                )
                .frame(width: 156, height: 156)
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotationReverse))
        }
    }

    // MARK: - Orbiters

    private var orbitLayer: some View {
        ZStack {
            ForEach(orbiters) { orbiter in
                let useReverse = orbiter.startAngle.truncatingRemainder(dividingBy: 120) == 60
                let phase = useReverse ? orbitPhaseReverse : orbitPhase
                let angle = (orbiter.startAngle + (reduceMotion ? 0 : phase)) * .pi / 180
                orbiterChip(orbiter: orbiter)
                    .offset(
                        x: cos(angle) * orbiter.radius,
                        y: sin(angle) * orbiter.radius
                    )
            }
        }
    }

    private func orbiterChip(orbiter: HeroOrbiter) -> some View {
        Image(systemName: orbiter.symbol)
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(orbiter.color)
            .accessibilityHidden(true)
            .frame(width: orbiter.size, height: orbiter.size)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(orbiter.color.opacity(0.30), lineWidth: 0.6)
            }
            .shadow(color: orbiter.color.opacity(0.30), radius: 6, y: 2)
    }

    // MARK: - Core

    private var coreLayer: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.85),
                            AppTheme.cyan,
                            AppTheme.violet,
                            AppTheme.accent.opacity(0.85)
                        ],
                        center: .center
                    )
                )
                .frame(width: 116, height: 116)
                .blur(radius: 0.6)
                .opacity(0.92)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 104, height: 104)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: "folder.fill")
                .font(.system(size: 44, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            lockBadge
        }
        .offset(y: reduceMotion ? 0 : coreOffset)
        .shadow(
            color: AppTheme.accent.opacity(coreGlow ? 0.50 : 0.30),
            radius: coreGlow ? 26 : 16,
            y: 8
        )
    }

    private var lockBadge: some View {
        ZStack {
            Circle()
                .fill(AppTheme.orange)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.20), lineWidth: 1)
                }
                .shadow(color: AppTheme.orange.opacity(0.45), radius: 6, y: 2)

            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        .offset(x: 36, y: -36 + lockBob)
        .accessibilityHidden(true)
    }

    // MARK: - Animation

    private func startAnimations() {
        if reduceMotion {
            coreGlow = true
            haloScale = 1.0
            coreOffset = 0
            return
        }

        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
            ringRotationReverse = -360
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
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            lockBob = -2
        }

        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            orbitPhase = 360
        }
        withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
            orbitPhaseReverse = 360
        }

        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            blobPhaseA = .pi * 2
        }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            blobPhaseB = .pi * 2
        }
    }
}

/// One orbiting developer-domain glyph that revolves around the central
/// folder in `PermissionRequiredHero`. Mirrors the `Orbiter` shape used by
/// `WelcomeHeroView` but is a separate type so each hero owns its data.
struct HeroOrbiter: Identifiable {
    let id: Int
    let symbol: String
    let color: Color
    let radius: CGFloat
    let speed: Double
    let size: CGFloat
    let startAngle: Double

    init(
        symbol: String,
        color: Color,
        radius: CGFloat,
        speed: Double,
        size: CGFloat,
        startAngle: Double
    ) {
        self.id = Int(startAngle)
        self.symbol = symbol
        self.color = color
        self.radius = radius
        self.speed = speed
        self.size = size
        self.startAngle = startAngle
    }
}
