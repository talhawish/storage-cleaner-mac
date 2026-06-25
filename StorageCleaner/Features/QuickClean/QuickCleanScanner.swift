import Foundation

/// Resolves the enabled `CleanupOption`s for a Quick Clean run. Reads the
/// `enabledCleanupOptions` `AppStorage` value and falls back to the
/// registry's safe-by-default set on first launch.
struct QuickCleanPreferences: Sendable {
    private static let storageKey = "enabledCleanupOptions"

    private let storage: @Sendable (String) -> String

    init(storage: @escaping @Sendable (String) -> String = { UserDefaults.standard.string(forKey: $0) ?? "" }) {
        self.storage = storage
    }

    var enabledOptionIDs: Set<String> {
        let raw = storage(Self.storageKey)
        let parsed = Set(raw.components(separatedBy: ",")).filter { !$0.isEmpty }
        return parsed.isEmpty ? CleanupOptionsRegistry.safeByDefaultIDs : parsed
    }
}

/// Runs a Quick Clean scan: walks the paths of every enabled `CleanupOption`,
/// keeps the ones that exist on disk, and groups them into a
/// `QuickCleanScan`. Pure data-in / data-out so it can be unit-tested without
/// SwiftUI.
struct QuickCleanScanner: Sendable {
    private let options: [CleanupOption]
    private let collector: FileSystemCollector
    private let permissionHandler: (any StoragePermissionHandling)?

    init(
        options: [CleanupOption] = CleanupOptionsRegistry.allOptions,
        enabledIDs: Set<String>? = nil,
        collector: FileSystemCollector = FileSystemCollector(),
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) {
        let enabled = enabledIDs ?? QuickCleanPreferences().enabledOptionIDs
        self.options = options.filter { enabled.contains($0.id) }
        self.collector = collector
        self.permissionHandler = permissionHandler
    }

    /// Walks every enabled option. The `progress` callback fires after each
    /// option completes (with the running totals) so the UI can render a live
    /// status without having to wait for the full scan.
    ///
    /// The walk is `Task.isCancelled`-aware; cancellation returns whatever
    /// categories have been collected so far.
    ///
    /// On a sandboxed build the scanner acquires security-scoped access to
    /// the home folder before measuring sizes — `FileManager`'s directory
    /// enumerator returns nothing for protected paths (e.g.
    /// `~/Library/Developer/Xcode/DerivedData`) without it, which would
    /// surface as `0 KB` for every item. If the user hasn't granted access
    /// the scan returns an empty `QuickCleanScan` with `accessDenied = true`
    /// so the view can prompt for permission instead of misleadingly showing
    /// "Nothing to clean".
    ///
    /// The `permissionHandler` is optional so tests can drive the scanner
    /// against synthetic paths without a permission layer; in that case the
    /// scanner walks paths directly with no security scope. The acquire/
    /// release lifecycle is delegated to `withHomeFolderAccess` so the
    /// helper is the single source of truth for sandbox-aware scanning.
    func scan(
        progress: (@Sendable (Int, Int) async -> Void)? = nil
    ) async -> QuickCleanScan {
        guard let permissionHandler else {
            return await runScan(progress: progress)
        }
        return await permissionHandler.withHomeFolderAccess { access in
            guard access != nil else {
                return QuickCleanScan(categories: [], accessDenied: true)
            }
            return await runScan(progress: progress)
        }
    }

    /// Walks every enabled option under whatever security scope the caller
    /// has already arranged. The `progress` callback fires after each option
    /// completes so the UI can render a live status.
    private func runScan(
        progress: (@Sendable (Int, Int) async -> Void)?
    ) async -> QuickCleanScan {
        var categories: [QuickCleanCategory] = []
        let total = options.count

        for (index, option) in options.enumerated() {
            if Task.isCancelled { break }

            let urls = option.paths.map { pathString -> URL in
                let expanded = UserHomeDirectory.expandingTilde(in: pathString)
                return URL(fileURLWithPath: expanded)
            }

            let collection = collector.collectExistingItems(at: urls)
            let items = collection.candidates.map { candidate in
                QuickCleanItem(url: candidate.url, bytes: candidate.bytes)
            }

            // Sort biggest first so the most impactful items render at the top
            // of the review list — same convention as the rest of the app.
            let sorted = items.sorted { $0.bytes > $1.bytes }

            categories.append(QuickCleanCategory(
                id: option.id,
                name: option.name,
                summary: option.description,
                icon: option.icon,
                tint: option.resolvedTint,
                domain: option.domain,
                safety: option.safety,
                items: sorted
            ))

            await progress?(index + 1, total)
        }

        return QuickCleanScan(categories: categories)
    }
}
