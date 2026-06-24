import Foundation

/// Finds loose installer and package files (DMG, PKG, IPA, ISO, …) left behind in the user's
/// Downloads, Desktop, and Documents folders. These linger long after the app they installed and are
/// safe to review and remove. Android packages (`apk`/`aab`) are handled by `AndroidPackageScanner`,
/// so they are excluded here to avoid double-counting within the Leftovers section.
struct LeftoversScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .installerLeftovers
    let title = StorageFindingKind.installerLeftovers.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = DependencyPaths.Leftovers.searchRoots,
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .installerLeftovers,
            domain: .leftovers,
            roots: roots,
            safety: .review,
            collector: collector,
            matcher: Self.isLeftover
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }

    /// A file qualifies as a leftover installer when it has a known installer/package extension and
    /// is not hidden, inside an app bundle, or inside a build/dependency directory.
    static func isLeftover(_ url: URL) -> Bool {
        guard !url.lastPathComponent.hasPrefix(".") else { return false }
        let components = PathSafetyComponents.relevantComponents(for: url)
        guard components.isDisjoint(with: DependencyPaths.Leftovers.blockedPathComponents) else { return false }
        return DependencyPaths.Leftovers.installerExtensions.contains(url.pathExtension.lowercased())
    }
}
