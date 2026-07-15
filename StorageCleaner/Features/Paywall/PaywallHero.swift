import SwiftUI

/// Compact, motion-aware value summary used at the top of the paywall.
struct PaywallHero: View {
    struct Highlight: Identifiable, Equatable {
        let id: String
        let icon: String
        let title: String
        let tint: Color
    }

    let eyebrowIcon: String
    let eyebrowText: String
    let headline: String
    let subtitle: String
    let highlights: [Highlight]

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var didAppear = false
    @State private var ringRotation = 0.0
    @State private var blobPhase = 0.0

    var body: some View {
        ZStack {
            backgroundLayer
            content
        }
        .frame(maxWidth: .infinity)
        .clipShape(Rectangle())
        .onAppear(perform: startAnimations)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.10),
                    AppTheme.cyan.opacity(0.06),
                    AppTheme.violet.opacity(0.08),
                    AppTheme.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.35))
                    .frame(width: 240, height: 240)
                    .blur(radius: 90)
                    .offset(
                        x: didAppear ? cos(blobPhase) * 60 : 0,
                        y: didAppear ? sin(blobPhase * 0.7) * 24 : 0
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.30))
                    .frame(width: 200, height: 200)
                    .blur(radius: 90)
                    .offset(
                        x: didAppear ? cos(blobPhase * 0.6 + 2.0) * 50 : 0,
                        y: didAppear ? sin(blobPhase * 0.8 + 1.0) * 30 : 0
                    )
            }
        }
    }

    private var content: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.extraLarge) {
                textStack
                Spacer(minLength: 8)
                orb
                    .frame(width: 130, height: 130)
                    .accessibilityHidden(true)
            }

            textStack
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow
            headlineLabel
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            highlightsRow
                .padding(.top, 6)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var eyebrow: some View {
        Label(eyebrowText, systemImage: eyebrowIcon)
            .font(.caption.bold())
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.accent.opacity(0.12), in: Capsule())
            .overlay {
                Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.5)
            }
            .opacity(didAppear ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.05),
                value: didAppear
            )
    }

    private var headlineLabel: some View {
        Text(headline)
            .font(.largeTitle.bold())
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.primary, Color.primary.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(didAppear ? 1 : 0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.10),
                value: didAppear
            )
    }

    private var highlightsRow: some View {
        CenteredFlowLayout(spacing: 8) {
            ForEach(highlights) { highlight in
                PaywallHighlightChip(highlight: highlight)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.18),
            value: didAppear
        )
    }

    private var orb: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0),
                            AppTheme.accent.opacity(0.75),
                            AppTheme.cyan.opacity(0.65),
                            AppTheme.violet.opacity(0.65),
                            AppTheme.accent.opacity(0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.4
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
                .blur(radius: 0.4)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 92, height: 92)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 24, y: 8)
    }

    private func startAnimations() {
        if reduceMotion {
            didAppear = true
            return
        }
        withAnimation(.snappy(duration: 0.5).delay(0.05)) {
            didAppear = true
        }
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            blobPhase = .pi * 2
        }
    }

}
