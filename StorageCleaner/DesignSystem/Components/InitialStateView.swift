import SwiftUI

/// Pre-scan "ready to discover" hero used on every section the user reaches
/// before a scan has ever run. Distinct from `EmptyStateView`, which is the
/// calmer post-scan empty result; this is the welcoming, animated first
/// impression.
///
/// The hero composes four animated layers — a slow gradient ring, a pulsing
/// halo, a floating core, and small orbiting satellite symbols — so the page
/// reads as alive rather than as a "nothing here" message. The body explains
/// what the scan will look for and offers a prominent primary action.
struct InitialStateView: View {
    let title: String
    let subtitle: String
    let highlights: [InitialStateHighlight]
    let actionTitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var ringRotation = 0.0
    @State private var haloScale: CGFloat = 1.0
    @State private var coreOffset: CGFloat = 0
    @State private var isGlowing = false
    @State private var satellitePhase: Double = 0

    init(
        title: String,
        subtitle: String,
        highlights: [InitialStateHighlight] = [],
        actionTitle: String = "Start Scan",
        systemImage: String = "arrow.clockwise",
        tint: Color = AppTheme.accent,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.highlights = highlights
        self.actionTitle = actionTitle
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.extraLarge) {
            animatedHero
                .frame(width: 188, height: 188)
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.medium) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 520)
            }

            if !highlights.isEmpty {
                highlightsRow
            }

            Button(action: action) {
                Label(actionTitle, systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .shadow(color: tint.opacity(isGlowing ? 0.45 : 0.18), radius: isGlowing ? 24 : 12, y: 6)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: isGlowing
            )
            .accessibilityIdentifier("initial-state-scan-button")
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .onAppear { startAnimations() }
    }

    // MARK: - Hero layers

    private var animatedHero: some View {
        ZStack {
            haloLayer
            ringLayer
            satelliteLayer
            coreLayer
        }
    }

    /// Outermost gradient ring rotating very slowly to give the hero ambient
    /// motion without pulling focus from the icon.
    private var ringLayer: some View {
        Circle()
            .strokeBorder(
                AngularGradient(
                    colors: [
                        tint.opacity(0.0),
                        tint.opacity(0.55),
                        tint.opacity(0.0)
                    ],
                    center: .center
                ),
                lineWidth: 1.4
            )
            .frame(width: 184, height: 184)
            .rotationEffect(.degrees(ringRotation))
    }

    /// Soft pulsing halo behind the core; communicates "ready" without being
    /// demanding.
    private var haloLayer: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.20), tint.opacity(0.0)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 110
                    )
                )
                .scaleEffect(haloScale)
        }
    }

    /// Core badge: the familiar tinted circle + SF Symbol, gently floating up
    /// and down like the orb in `StorageOrbView`.
    private var coreLayer: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 132, height: 132)
                .overlay {
                    Circle().fill(tint.opacity(0.10))
                }
                .overlay {
                    Circle().strokeBorder(tint.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .offset(y: coreOffset)
        .shadow(color: tint.opacity(0.35), radius: 24, y: 8)
    }

    /// Three small satellite glyphs that orbit the core to give the hero
    /// parallax life. The icons are derived from `highlights` when available
    /// (so each page gets its own little visual signature), otherwise a
    /// generic trio.
    private var satelliteLayer: some View {
        let symbols: [String] = {
            if highlights.count >= 3 {
                return Array(highlights.prefix(3).map(\.systemImage))
            }
            return ["internaldrive", "doc.badge.ellipsis", "trash"]
        }()

        return ZStack {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                let angle = (satellitePhase + Double(index) * 120) * .pi / 180
                let radius: CGFloat = 96
                satelliteChip(symbol: symbol)
                    .offset(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )
            }
        }
    }

    private func satelliteChip(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(.regularMaterial, in: Circle())
            .overlay {
                Circle().strokeBorder(tint.opacity(0.20), lineWidth: 0.5)
            }
            .shadow(color: tint.opacity(0.25), radius: 6, y: 2)
            .accessibilityHidden(true)
    }

    // MARK: - Highlights

    private var highlightsRow: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ForEach(highlights) { highlight in
                VStack(spacing: 6) {
                    Image(systemName: highlight.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(tint.opacity(0.10), in: Circle())
                        .accessibilityHidden(true)

                    Text(highlight.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: 560)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Animation

    private func startAnimations() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            haloScale = 1.08
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            coreOffset = -4
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            isGlowing = true
        }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
            satellitePhase = 360
        }
    }
}

/// One labelled "what the scan will look for" pill rendered inside an
/// `InitialStateView`. The icon doubles as a satellite glyph in the hero, so
/// prefer using distinct SF Symbols.
struct InitialStateHighlight: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let systemImage: String
}
