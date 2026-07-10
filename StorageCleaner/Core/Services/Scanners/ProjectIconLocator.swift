import Foundation

/// Scores how likely a file is a project's icon/logo, purely from its name and
/// the directory that contains it. Pure and allocation-light so it can run for
/// every file during the scanner's single metrics pass without a second walk.
///
/// Recognises the conventional locations across ecosystems: Xcode/iOS/macOS
/// (`*.appiconset`), Android/Flutter (`mipmap-*/ic_launcher`), and the generic
/// web/repo patterns (`logo`, `icon`, `favicon`, `apple-touch-icon`, `Icon-192`).
enum ProjectIconLocator {
    /// Formats the project thumbnail loader can decode. Raster formats are
    /// handled by ImageIO; SVG favicons/logos are rasterized by `SVGImageRenderer`.
    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "ico", "webp", "heic", "tiff", "gif", "icns", "svg"
    ]

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

    /// A shallow pass over conventional app-icon directories. This avoids a
    /// broad second walk while still covering Flutter/iOS/Android/web layouts
    /// where the app icon lives under a well-known nested folder.
    static func commonIconCandidates(in root: URL, fileManager: FileManager = .default) -> [URL] {
        commonIconDirectorySubpaths
            .map { root.appending(path: $0, directoryHint: .isDirectory) }
            .flatMap { imageFiles(in: $0, fileManager: fileManager) }
            + androidMipmapCandidates(in: root, fileManager: fileManager)
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

    private static let commonIconDirectorySubpaths = [
        "",
        "web",
        "web/icons",
        "public",
        "public/icons",
        "static",
        "static/icons",
        "app",
        "assets",
        "assets/images",
        "src/app",
        "src/assets",
        "src/assets/images",
        "resources",
        "Resources",
        "Assets.xcassets/AppIcon.appiconset",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset",
        "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    ]

    private static func androidMipmapCandidates(in root: URL, fileManager: FileManager) -> [URL] {
        [
            "android/app/src/main/res",
            "android/app/src/debug/res",
            "android/app/src/profile/res",
            "app/src/main/res",
            "src/main/res"
        ]
        .map { root.appending(path: $0, directoryHint: .isDirectory) }
        .flatMap { resDirectory -> [URL] in
            guard let contents = try? fileManager.contentsOfDirectory(
                at: resDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return [] }

            return contents
                .filter { $0.lastPathComponent.lowercased().hasPrefix("mipmap") }
                .flatMap { imageFiles(in: $0, fileManager: fileManager) }
        }
    }

    private static func imageFiles(in directory: URL, fileManager: FileManager) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.filter { url in
            let parent = directory.lastPathComponent
            return score(fileName: url.lastPathComponent, parentDirectory: parent) > 0
        }
    }

    private static func fileExtension(of fileName: String) -> String {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return "" }
        return String(fileName[fileName.index(after: dot)...]).lowercased()
    }
}
