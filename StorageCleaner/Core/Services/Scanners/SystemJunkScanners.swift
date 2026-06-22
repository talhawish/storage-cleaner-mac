import Foundation

/// Builds the list of orphan directories under a Library root. An entry is orphaned when no
/// installed app's `CFBundleIdentifier` (or directory name) matches it. Shared by the
/// Application Support, Caches, and Containers scanners.
struct OrphanDirectoryResolver: Sendable {
    let root: URL
    let catalog: any OrphanCatalog
    let limit: Int

    func resolveOrphans() -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        let orphanURLs = entries.compactMap { url -> URL? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            let name = url.lastPathComponent
            guard !name.isEmpty, !name.hasPrefix(".") else { return nil }
            return catalog.ownsLibraryEntry(named: name) ? nil : url
        }

        return Array(
            orphanURLs
                .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
                .prefix(limit)
        )
    }
}

/// Identifies whether a Library entry is owned by an installed app. A `false` answer means the
/// entry is orphaned (the user can review and remove it). Conformed to by the live
/// `InstalledAppCatalog` and by tests that inject a fixed set of installed bundle IDs.
protocol OrphanCatalog: Sendable {
    func ownsLibraryEntry(named entryName: String) -> Bool
}

extension InstalledAppCatalog: OrphanCatalog {}

/// Shared engine for scanners that surface *orphaned* directories in user Library folders. Each
/// one wraps an `OrphanDirectoryResolver` so the engine stays testable in isolation.
struct OrphanedDirectoriesScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let resolvers: [OrphanDirectoryResolver]
    private let collector: FileSystemCollector
    private let safety: CleanupSafety
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        resolvers: [OrphanDirectoryResolver],
        collector: FileSystemCollector,
        safety: CleanupSafety = .review,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.kind = kind
        self.title = kind.title
        self.resolvers = resolvers
        self.collector = collector
        self.safety = safety
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let orphans = resolvers.flatMap { $0.resolveOrphans() }
        let candidates = collector.collectExistingItems(at: orphans).candidates
        let finding = builder.makeFinding(
            kind: kind,
            domain: .systemJunk,
            candidates: candidates,
            safety: safety
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: candidates.count,
            message: finding == nil
                ? "No orphaned \(kind.title.lowercased()) found"
                : "Found \(candidates.count) orphaned \(kind.title.lowercased())"
        )
    }
}

/// Orphaned `.plist` files at the top level of `~/Library/Preferences`. Matches the file's
/// stem against the installed-app catalog (e.g. `com.example.MyApp.plist` → `com.example.MyApp`).
struct OrphanedPreferencesScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .orphanedAppPreferences
    let title = StorageFindingKind.orphanedAppPreferences.title
    private let root: URL
    private let catalog: any OrphanCatalog
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        root: URL = DependencyPaths.SystemJunk.preferences,
        catalog: any OrphanCatalog,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.root = root
        self.catalog = catalog
        self.collector = collector
        self.builder = builder
    }

    /// Test-only initializer that takes a custom root so unit tests can run against a temporary
    /// `Library` without touching the host's `~/Library/Preferences`.
    internal init(
        catalog: any OrphanCatalog,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder(),
        root: URL
    ) {
        self.root = root
        self.catalog = catalog
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let orphans = orphanPlistURLs()
        let candidates = collector.collectExistingItems(at: orphans).candidates
        let finding = builder.makeFinding(
            kind: kind,
            domain: .systemJunk,
            candidates: candidates,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: candidates.count,
            message: finding == nil
                ? "No orphaned preference files found"
                : "Found \(candidates.count) orphaned preference files"
        )
    }

    private func orphanPlistURLs() -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: root.path) else { return [] }
        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return []
        }

        return entries.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                return nil
            }
            guard url.pathExtension.lowercased() == "plist" else { return nil }
            let stem = url.deletingPathExtension().lastPathComponent
            guard !stem.isEmpty else { return nil }
            return catalog.ownsLibraryEntry(named: stem) ? nil : url
        }
    }
}

/// Walks `~/Library/Logs/DiagnosticReports` and `~/Library/Logs/CrashReporter` for stale crash
/// reports and diagnostic logs. Crash reports are user-owned by the system, not by any
/// app, so they do not use `InstalledAppCatalog`. The discovery is dynamic: only reports that
/// actually exist are surfaced.
struct OldCrashReportsScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .oldCrashReports
    let title = StorageFindingKind.oldCrashReports.title
    private let roots: [URL]
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        roots: [URL] = [
            DependencyPaths.SystemJunk.diagnosticReports,
            DependencyPaths.SystemJunk.crashReporter
        ],
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.roots = roots
        self.collector = collector
        self.builder = builder
    }

    /// Test-only initializer that accepts custom roots so unit tests can run against a temporary
    /// `Library` without touching the host's diagnostic logs.
    internal init(
        collector: FileSystemCollector,
        roots: [URL],
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.roots = roots
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let result = collector.collectFiles(
            at: roots,
            matching: Self.isCrashReport,
            prioritizeLargest: true
        )
        let finding = builder.makeFinding(
            kind: kind,
            domain: .systemJunk,
            candidates: result.candidates,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: result.inspectedItemCount,
            message: finding == nil
                ? "No crash reports found"
                : "Found \(result.candidates.count) crash reports"
        )
    }

    private static func isCrashReport(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return [
            "crash",
            "diag",
            "hang",
            "ips",
            "memory",
            "panic",
            "spin",
            "synced"
        ].contains(ext)
    }
}

// MARK: - Concrete scanners

struct OrphanedAppSupportScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .orphanedAppSupport
    let title = StorageFindingKind.orphanedAppSupport.title
    private let scanner: OrphanedDirectoriesScanner

    init(collector: FileSystemCollector, catalog: any OrphanCatalog) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppSupport,
            resolvers: [OrphanDirectoryResolver(
                root: DependencyPaths.SystemJunk.applicationSupport,
                catalog: catalog,
                limit: 200
            )],
            collector: collector
        )
    }

    /// Test-only initializer that accepts custom roots so unit tests can run against a temporary
    /// `Library` without touching the host's `~/Library/Application Support`.
    internal init(
        collector: FileSystemCollector,
        catalog: any OrphanCatalog,
        root: URL
    ) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppSupport,
            resolvers: [OrphanDirectoryResolver(root: root, catalog: catalog, limit: 200)],
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct OrphanedAppCachesScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .orphanedAppCaches
    let title = StorageFindingKind.orphanedAppCaches.title
    private let scanner: OrphanedDirectoriesScanner

    init(collector: FileSystemCollector, catalog: any OrphanCatalog) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppCaches,
            resolvers: [OrphanDirectoryResolver(
                root: DependencyPaths.SystemJunk.caches,
                catalog: catalog,
                limit: 200
            )],
            collector: collector
        )
    }

    /// Test-only initializer that accepts a custom root so unit tests can run against a temporary
    /// `Library` without touching the host's `~/Library/Caches`.
    internal init(
        collector: FileSystemCollector,
        catalog: any OrphanCatalog,
        root: URL
    ) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppCaches,
            resolvers: [OrphanDirectoryResolver(root: root, catalog: catalog, limit: 200)],
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct OrphanedAppContainersScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .orphanedAppContainers
    let title = StorageFindingKind.orphanedAppContainers.title
    private let scanner: OrphanedDirectoriesScanner

    init(collector: FileSystemCollector, catalog: any OrphanCatalog) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppContainers,
            resolvers: [
                OrphanDirectoryResolver(
                    root: DependencyPaths.SystemJunk.containers,
                    catalog: catalog,
                    limit: 200
                ),
                OrphanDirectoryResolver(
                    root: DependencyPaths.SystemJunk.groupContainers,
                    catalog: catalog,
                    limit: 200
                )
            ],
            collector: collector
        )
    }

    /// Test-only initializer that accepts custom roots so unit tests can run against a temporary
    /// `Library` without touching the host's `~/Library/Containers` or `~/Library/Group Containers`.
    internal init(
        collector: FileSystemCollector,
        catalog: any OrphanCatalog,
        root: URL,
        groupContainersRoot: URL
    ) {
        scanner = OrphanedDirectoriesScanner(
            kind: .orphanedAppContainers,
            resolvers: [
                OrphanDirectoryResolver(root: root, catalog: catalog, limit: 200),
                OrphanDirectoryResolver(root: groupContainersRoot, catalog: catalog, limit: 200)
            ],
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
