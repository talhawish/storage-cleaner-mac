import SwiftUI

/// Resolves the accent color for a Quick Clean category. Prefers the
/// `StorageDomain` accent, falling back to the option's `iconColor` for
/// domains that map to `.secondary` (e.g. `.otherCaches`). Centralized so
/// the view, the category card, and the success breakdown stay in sync.
enum QuickCleanPalette {
    private static let swatches: [String: Color] = [
        "blue": AppTheme.accent,
        "cyan": AppTheme.cyan,
        "mint": AppTheme.mint,
        "orange": AppTheme.orange,
        "pink": AppTheme.pink,
        "rose": AppTheme.rose,
        "indigo": AppTheme.indigo,
        "teal": AppTheme.teal,
        "violet": AppTheme.violet,
        "yellow": .yellow,
        "red": .red,
        "green": .green,
        "purple": AppTheme.violet,
        "gray": .gray
    ]

    static func color(for category: QuickCleanCategory) -> Color {
        let domainColor = AppTheme.color(for: category.domain)
        if domainColor != .secondary {
            return domainColor
        }
        return fromString(category.iconColor)
    }

    static func fromString(_ name: String) -> Color {
        swatches[name, default: .secondary]
    }
}
