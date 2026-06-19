import Foundation

/// Scores how likely a file is a project's icon/logo, purely from its name and
/// the directory that contains it. Pure and allocation-light so it can run for
/// every file during the scanner's single metrics pass without a second walk.
///
/// Recognises the conventional locations across ecosystems: Xcode/iOS/macOS
/// (`*.appiconset`), Android/Flutter (`mipmap-*/ic_launcher`), and the generic
/// web/repo patterns (`logo`, `icon`, `favicon`, `apple-touch-icon`, `Icon-192`).
enum ProjectIconLocator {
    /// Raster formats the thumbnail loader can decode. SVG is intentionally
    /// excluded — it cannot be rasterised by ImageIO, so picking one would just
    /// fall back to the placeholder symbol and crowd out a usable raster.
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "ico", "webp", "heic", "tiff", "gif", "icns"]

    /// A score of 0 means "not an icon". Higher means a stronger match.
    static func score(fileName: String, parentDirectory: String) -> Int {
        let ext = fileExtension(of: fileName)
        guard imageExtensions.contains(ext) else { return 0 }

        let base = String(fileName.dropLast(ext.count + 1)).lowercased()
        let parent = parentDirectory.lowercased()

        if parent.hasSuffix(".appiconset") { return 100 }
        if parent.hasPrefix("mipmap") {
            return base.hasPrefix("ic_launcher") ? 95 : 80
        }
        return nameScore(base: base)
    }

    /// Score from the file's base name alone, used when the directory carries no
    /// platform-specific signal.
    private static func nameScore(base: String) -> Int {
        if let exact = exactNameScores[base] { return exact }
        if strongPrefixes.contains(where: base.hasPrefix) { return 50 }
        if base.contains("logo") { return 40 }
        if base.contains("launcher") || base.contains("appicon") { return 35 }
        if base.contains("icon") { return 30 }
        return 0
    }

    private static let exactNameScores: [String: Int] = [
        "logo": 70,
        "icon": 68, "appicon": 68, "app-icon": 68, "app_icon": 68,
        "apple-touch-icon": 62,
        "favicon": 55
    ]

    private static let strongPrefixes = ["icon-", "logo-", "logo@"]

    private static func fileExtension(of fileName: String) -> String {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return "" }
        return String(fileName[fileName.index(after: dot)...]).lowercased()
    }
}
