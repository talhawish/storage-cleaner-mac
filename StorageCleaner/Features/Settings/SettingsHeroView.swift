import SwiftUI

/// The hero block at the top of the in-app Settings page. Establishes the
/// page's identity ("Preferences / Settings") and offers a one-glance
/// summary of the user's current configuration.
///
/// Visual treatment matches the dashboard's `WelcomeHeroView` and the
/// paywall's `PaywallHero` — a subtle aurora background, an eyebrow chip,
/// a large gradient headline, and three compact "status" chips at the
/// bottom (Scope, Review, Large Files). All motion honors
/// `accessibilityReduceMotion`.
struct SettingsHeroView: View {
    let scanScope: String
    let reviewItemsEnabled: Bool
    let largeFileThreshold: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var didAppear = false
    @State private var blobPhaseA: Double = 0
    @State private var blobPhaseB: Double = 0
    @State private var ringRotation: Double = 0

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.extraLarge) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                eyebrow
                headline
                subtitle
                statusRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            visual
                .frame(width: 168, height: 168)
                .accessibilityHidden(true)
        }
        .padding(AppTheme.Spacing.huge)
        .background(backgroundLayer)
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
        .shadow(color: AppTheme.accent.opacity(0.18), radius: 28, y: 14)
        .onAppear(perform: startAnimations)
    }

    // MARK: - Content

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text("Preferences")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .tracking(0.4)
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
        Text("Settings")
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .lineSpacing(1)
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
            .animation(.easeOut(duration: 0.5).delay(0.10), value: didAppear)
    }

    private var subtitle: some View {
        Text(
            "Tune scanning, Quick Clean, safety behavior, and the way "
            + "Storage Cleaner presents results."
        )
        .font(.body)
        .foregroundStyle(.secondary)
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.18), value: didAppear)
    }

    private var statusRow: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            SettingsStatusPill(title: "Scope", value: scanScope, icon: "externaldrive.fill", tint: AppTheme.accent)
            SettingsStatusPill(
                title: "Review",
                value: reviewItemsEnabled ? "Visible" : "Hidden",
                icon: "eye.fill",
                tint: AppTheme.violet
            )
            SettingsStatusPill(
                title: "Large Files",
                value: largeFileThreshold,
                icon: "doc.badge.ellipsis",
                tint: AppTheme.cyan
            )
        }
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.26), value: didAppear)
    }

    // MARK: - Visual

    private var visual: some View {
        ZStack {
            Circle()
                .fill(AppTheme.surface.opacity(0.4))
                .overlay {
                    Circle().stroke(AppTheme.hairline, lineWidth: 1)
                }

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
                    lineWidth: 1.4
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
                .blur(radius: 0.4)

            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 56, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
        }
        .shadow(color: AppTheme.accent.opacity(0.30), radius: 18, y: 8)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            AppTheme.appBackground

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.40))
                    .frame(width: 320, height: 320)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseA) * 70 : 0,
                        y: didAppear ? sin(blobPhaseA * 0.8) * 40 : 0
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.32))
                    .frame(width: 260, height: 260)
                    .blur(radius: 110)
                    .offset(
                        x: didAppear ? cos(blobPhaseB * 0.9 + 1.5) * 60 : 0,
                        y: didAppear ? sin(blobPhaseB) * 50 : 0
                    )
            }

            LinearGradient(
                colors: [
                    Color.primary.opacity(0.0),
                    Color.primary.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Animation

    private func startAnimations() {
        if reduceMotion {
            didAppear = true
            return
        }
        withAnimation(.snappy(duration: 0.5).delay(0.05)) {
            didAppear = true
        }
        withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
            blobPhaseA = .pi * 2
        }
        withAnimation(.linear(duration: 32).repeatForever(autoreverses: false)) {
            blobPhaseB = .pi * 2
        }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }
}

/// One of three compact "status" pills in the settings hero. Mirrors the
/// `StatCardTab` rhythm but rendered as a single-line tile that fits on
/// the hero's bottom row.
struct SettingsStatusPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
