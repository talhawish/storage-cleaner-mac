import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 18
    static let contentSpacing: CGFloat = 20

    static let accent = Color(red: 0.25, green: 0.47, blue: 0.98)
    static let cyan = Color(red: 0.16, green: 0.72, blue: 0.88)
    static let mint = Color(red: 0.20, green: 0.76, blue: 0.60)
    static let orange = Color(red: 0.96, green: 0.56, blue: 0.22)
    static let pink = Color(red: 0.94, green: 0.35, blue: 0.62)
    static let rose = Color(red: 0.96, green: 0.42, blue: 0.48)
    static let indigo = Color(red: 0.38, green: 0.45, blue: 0.96)
    static let teal = Color(red: 0.18, green: 0.68, blue: 0.66)
    static let violet = Color(red: 0.58, green: 0.40, blue: 0.96)

    static func color(for domain: StorageDomain) -> Color {
        color(for: domain.accentColor)
    }

    private static func color(for accentColor: StorageAccentColor) -> Color {
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
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }
}
