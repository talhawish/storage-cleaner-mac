import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 18
    static let contentSpacing: CGFloat = 20

    /// Spacing scale. Use these instead of ad-hoc literals for consistent rhythm.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
    }

    /// Icon point sizes by context.
    enum IconSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let sub: CGFloat = 20
        static let title: CGFloat = 28
        static let hero: CGFloat = 56
    }

    /// Adaptive hairline border for card surfaces. Resolves to a subtle dark line in light mode and
    /// a subtle light line in dark mode, so card edges stay defined in both appearances. Replaces
    /// hardcoded `.white.opacity(...)` strokes, which are invisible over light material.
    static let hairline = Color.primary.opacity(0.08)

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
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
