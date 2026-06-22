import SwiftUI

/// Orbital glyph used inside `WelcomeHeroView`'s hero composition. A small
/// developer-domain SF Symbol that revolves around the central core at its
/// own radius, speed, and starting angle.
struct Orbiter: Identifiable {
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

/// Twinkling dot in `WelcomeHeroView`'s starfield. Each star pulses
/// independently so the field never feels mechanical.
struct Star: Identifiable {
    let id = UUID()
    let offsetX: CGFloat
    let offsetY: CGFloat
    let size: CGFloat
    let twinkleSpeed: Double
    let twinkleOffset: Double
}

/// A subtle "⌘R" hint next to the primary CTA in `WelcomeHeroView`, so the
/// keyboard shortcut is discoverable without dominating the hero.
struct KeyboardHintBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("⌘")
            Text("R")
        }
        .font(.caption.weight(.semibold).monospaced())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Text side of `WelcomeHeroView`: eyebrow chip, gradient headline,
/// subtitle, primary CTA, and the ⌘R shortcut hint. Extracted to keep the
/// parent's body length under the SwiftLint ceiling.
struct WelcomeHeroText: View {
    let startScan: () -> Void
    let didAppear: Bool
    let coreGlow: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            eyebrow
            headline
            subtitle
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text("Developer-aware analysis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.accent.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.5)
        }
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.05), value: didAppear)
    }

    private var headline: some View {
        Text("Find the space your tools leave behind.")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.primary,
                        Color.primary.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(didAppear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.12), value: didAppear)
    }

    private var subtitle: some View {
        Text(
            "Scan build artifacts, simulators, package caches, browser caches, "
            + "large videos, photos, screenshots, Trash, leftover APKs, "
            + "containers, and local AI models. You stay in control of every cleanup."
        )
        .font(.body)
        .foregroundStyle(.secondary)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.20), value: didAppear)
    }

    private var actions: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Button(action: startScan) {
                Label("Start Smart Scan", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(minWidth: 170)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .shadow(
                color: AppTheme.accent.opacity(coreGlow ? 0.45 : 0.18),
                radius: coreGlow ? 22 : 12,
                y: 6
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: coreGlow
            )
            .accessibilityIdentifier("primary-scan-button")
            .accessibilityHint("Scans developer storage locations without deleting files")

            KeyboardHintBadge()
        }
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.28), value: didAppear)
    }
}

/// Drifting aurora background used behind `WelcomeHeroView`'s text and
/// visual compositions. Three blurred color blobs that orbit slowly under
/// phase animation, plus a top-down wash to keep foreground text contrast
/// in both light and dark mode. The background is a stateless view — all
/// motion state lives on the parent and is bound in.
struct WelcomeHeroBackground: View {
    let didAppear: Bool
    let blobPhaseA: Double
    let blobPhaseB: Double
    let blobPhaseC: Double
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            AppTheme.appBackground

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.55))
                    .frame(width: 360, height: 360)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseA) * 90 : 0,
                        y: didAppear ? sin(blobPhaseA * 0.8) * 50 : 0
                    )

                Circle()
                    .fill(AppTheme.cyan.opacity(0.45))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseB * 0.9 + 1.5) * 80 : 0,
                        y: didAppear ? sin(blobPhaseB) * 60 : 0
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.45))
                    .frame(width: 280, height: 280)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseC * 0.7 + 3.0) * 100 : 0,
                        y: didAppear ? sin(blobPhaseC * 0.6 + 2.0) * 70 : 0
                    )
            }

            LinearGradient(
                colors: [
                    Color.primary.opacity(0.0),
                    Color.primary.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Visual side of `WelcomeHeroView`: ambient aurora background, starfield,
/// pulsing halo, counter-rotating aurora rings, orbiting developer-domain
/// glyphs, and the central glowing core. All motion is driven by the
/// parent via the bound animation state.
struct WelcomeHeroVisual: View {
    let orbiters: [Orbiter]
    let stars: [Star]
    let didAppear: Bool
    let blobPhaseA: Double
    let blobPhaseB: Double
    let blobPhaseC: Double
    let twinklePhase: Double
    let coreOffset: CGFloat
    let coreGlow: Bool
    let ringRotation: Double
    let ringRotationReverse: Double
    let orbitPhase: Double
    let orbitPhaseReverse: Double
    let haloScale: CGFloat
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            backgroundLayer
            starLayer
            haloLayer
            auroraRings
            orbitLayer
            coreLayer
        }
    }

    // MARK: Background

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.appBackground

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.55))
                    .frame(width: 360, height: 360)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseA) * 90 : 0,
                        y: didAppear ? sin(blobPhaseA * 0.8) * 50 : 0
                    )

                Circle()
                    .fill(AppTheme.cyan.opacity(0.45))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseB * 0.9 + 1.5) * 80 : 0,
                        y: didAppear ? sin(blobPhaseB) * 60 : 0
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.45))
                    .frame(width: 280, height: 280)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseC * 0.7 + 3.0) * 100 : 0,
                        y: didAppear ? sin(blobPhaseC * 0.6 + 2.0) * 70 : 0
                    )
            }

            LinearGradient(
                colors: [
                    Color.primary.opacity(0.0),
                    Color.primary.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: Stars

    private var starLayer: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: star.size, height: star.size)
                    .offset(x: star.offsetX, y: star.offsetY)
                    .opacity(reduceMotion
                             ? 0.7
                             : 0.35 + 0.5 * (0.5 + 0.5 * sin(twinklePhase * star.twinkleSpeed + star.twinkleOffset)))
                    .blur(radius: star.size < 1.6 ? 0.4 : 0)
            }
        }
    }

    // MARK: Halo

    private var haloLayer: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        AppTheme.accent.opacity(reduceMotion ? 0.18 : (haloScale > 1.0 ? 0.24 : 0.16)),
                        AppTheme.accent.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: 40,
                    endRadius: 160
                )
            )
            .scaleEffect(reduceMotion ? 1.0 : haloScale)
    }

    // MARK: Aurora rings

    private var auroraRings: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.0),
                            AppTheme.accent.opacity(0.65),
                            AppTheme.cyan.opacity(0.55),
                            AppTheme.violet.opacity(0.55),
                            AppTheme.accent.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.6
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
                .blur(radius: 0.5)

            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.violet.opacity(0.0),
                            AppTheme.violet.opacity(0.55),
                            AppTheme.pink.opacity(0.45),
                            AppTheme.accent.opacity(0.45),
                            AppTheme.violet.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.2
                )
                .frame(width: 196, height: 196)
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotationReverse))
        }
    }

    // MARK: Orbits

    private var orbitLayer: some View {
        ZStack {
            ForEach(orbiters) { orbiter in
                let useReverse = orbiter.id.isMultiple(of: 2) == false
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

    private func orbiterChip(orbiter: Orbiter) -> some View {
        Image(systemName: orbiter.symbol)
            .font(.system(size: 16, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(orbiter.color)
            .accessibilityHidden(true)
            .frame(width: orbiter.size, height: orbiter.size)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(orbiter.color.opacity(0.30), lineWidth: 0.6)
            }
            .shadow(color: orbiter.color.opacity(0.35), radius: 8, y: 3)
    }

    // MARK: Core

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
                .frame(width: 132, height: 132)
                .blur(radius: 0.6)
                .opacity(0.95)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 118, height: 118)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: "internaldrive.fill")
                .font(.system(size: 52, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
        }
        .offset(y: reduceMotion ? 0 : coreOffset)
        .shadow(color: AppTheme.accent.opacity(coreGlow ? 0.55 : 0.35), radius: 28, y: 10)
    }
}
