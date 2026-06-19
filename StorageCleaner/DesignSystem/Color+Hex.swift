import SwiftUI

extension Color {
    /// Create a colour from a 6-digit RGB hex string (e.g. `"34C759"`).
    /// Invalid input falls back to black, never crashes.
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255,
            blue: Double(rgbValue & 0x0000FF) / 255
        )
    }
}
