import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = Radius.card
    static let contentSpacing: CGFloat = 20

    /// Corner-radius scale. Use these instead of ad-hoc literals so rounded
    /// corners stay consistent across the app (enforced by the
    /// `no_radius_literal` SwiftLint rule).
    enum Radius {
        /// Tiny inline chips and swatches.
        static let tiny: CGFloat = 4
        /// Small controls: badges, small buttons, thumbnails.
        static let small: CGFloat = 8
        /// Compact chips and pills.
        static let chip: CGFloat = 10
        /// Standard controls and inner cards.
        static let medium: CGFloat = 12
        /// Prominent controls and grouped rows.
        static let control: CGFloat = 14
        /// Large tiles and content wells.
        static let large: CGFloat = 16
        /// Top-level cards (the `cardSurface()` radius).
        static let card: CGFloat = 18
        /// Modal sheets (`AppModal`).
        static let modal: CGFloat = 22
    }

    /// Spacing scale. Use these instead of ad-hoc literals for consistent rhythm.
    enum Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let mediumLarge: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 28
        static let huge: CGFloat = 40
    }

    /// Semantic text styles for the roles repeated across screens — one source
    /// of truth for stat numerals, hero values, and icon fonts so screens stay
    /// visually consistent. Prefer these (or the built-in relative styles like
    /// `.title2`, `.subheadline`) over ad-hoc `.system(size:)` literals.
    enum Typography {
        /// Hero numeral on welcome/settings hero cards.
        static let heroValue = Font.system(size: 36, weight: .bold, design: .rounded)
        /// Large stat numeral on screen headers (e.g. total reclaimable bytes).
        static let statValue = Font.system(size: 28, weight: .bold, design: .rounded)
        /// Mid-size numeral in modals and summary bars; pair with `.monospacedDigit()`.
        static let summaryValue = Font.system(size: 22, weight: .bold, design: .rounded)
        /// SF Symbol font for screen-header hero icons.
        static let heroIcon = Font.system(size: IconSize.title, weight: .semibold)
        /// SF Symbol font for section/card leading icons.
        static let sectionIcon = Font.system(size: IconSize.sub, weight: .semibold)
        /// SF Symbol font for row/tile icons.
        static let bodyIcon = Font.system(size: IconSize.body, weight: .semibold)
        /// Emphasized row label / compact button text.
        static let rowLabel = Font.system(size: 14, weight: .semibold)
    }

    /// Icon point sizes by context.
    enum IconSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let sub: CGFloat = 20
        static let title: CGFloat = 28
        static let hero: CGFloat = 56
    }

    /// Metrics for the collapsed icon-only sidebar.
    enum MiniSidebar {
        static let width: CGFloat = 64
        static let buttonSize: CGFloat = 32
        static let iconSize: CGFloat = 16
        static let cornerRadius: CGFloat = 7
        static let footerHeight: CGFloat = 36
        static let statusIndicatorSize: CGFloat = 8
        static let statusPadding: CGFloat = 12
        static let itemSpacing: CGFloat = 4
        static let groupSpacing: CGFloat = 12
        static let verticalPadding: CGFloat = 12
    }

    /// Adaptive surfaces for card-heavy screens. Native control colors keep light mode readable while
    /// preserving the system appearance in dark mode.
    static let appBackground = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let subtleSurface = Color.primary.opacity(0.045)

    /// Adaptive hairline border for card surfaces. Resolves to a subtle dark line in light mode and
    /// a subtle light line in dark mode, so card edges stay defined in both appearances. Replaces
    /// hardcoded `.white.opacity(...)` strokes, which are invisible over light material.
    static let hairline = Color.primary.opacity(0.12)

    static let accent = Color(red: 0.25, green: 0.47, blue: 0.98)
    static let cyan = Color(red: 0.16, green: 0.72, blue: 0.88)
    static let mint = Color(red: 0.20, green: 0.76, blue: 0.60)
    static let orange = Color(red: 0.96, green: 0.56, blue: 0.22)
    static let pink = Color(red: 0.94, green: 0.35, blue: 0.62)
    static let rose = Color(red: 0.96, green: 0.42, blue: 0.48)
    static let indigo = Color(red: 0.38, green: 0.45, blue: 0.96)
    static let teal = Color(red: 0.18, green: 0.68, blue: 0.66)
    static let violet = Color(red: 0.58, green: 0.40, blue: 0.96)
    static let amber = Color(red: 0.93, green: 0.69, blue: 0.18)

    static func color(for domain: StorageDomain) -> Color {
        color(for: domain.accentColor)
    }

    static func color(for accentColor: StorageAccentColor) -> Color {
        accentPalette[accentColor, default: .secondary]
    }

    private static let accentPalette: [StorageAccentColor: Color] = [
        .blue: accent,
        .cyan: cyan,
        .mint: mint,
        .orange: orange,
        .pink: pink,
        .rose: rose,
        .indigo: indigo,
        .teal: teal,
        .violet: violet,
        .amber: amber,
        .gray: .gray,
        .secondary: .secondary
    ]
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
            .shadow(color: Color.primary.opacity(0.045), radius: 10, y: 4)
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
