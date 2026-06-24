import SwiftUI

/// A single CLI tool / toolchain root discovered by the scanner.
///
/// Unlike media files, each entry in the `cliApps` finding's `filePaths` is a
/// top-level program root (e.g. `~/.rustup`, `/opt/homebrew/Cellar`). The catalog
/// maps each root to a human-friendly descriptor so the UI can show what it is
/// instead of trying to render an image preview.
struct CLIProgram: Identifiable, Hashable {
    let url: URL
    let displayName: String
    let subtitle: String
    let symbolName: String
    let accent: Color
    let category: CLIProgramCategory
    let safety: CleanupSafety

    var id: URL { url }
}

/// Logical grouping used to section the CLI Programs list.
enum CLIProgramCategory: String, CaseIterable, Identifiable {
    case binary
    case homebrew
    case nodeGlobal
    case versionManager
    case toolchain
    case packageCache

    var id: String { rawValue }

    /// Display order in the list.
    var sortIndex: Int {
        switch self {
        case .binary: 0
        case .homebrew: 1
        case .nodeGlobal: 2
        case .versionManager: 3
        case .toolchain: 4
        case .packageCache: 5
        }
    }

    var title: String {
        switch self {
        case .binary: "Installed tools"
        case .homebrew: "Homebrew"
        case .nodeGlobal: "Global packages"
        case .versionManager: "Version managers"
        case .toolchain: "Toolchains & runtimes"
        case .packageCache: "Download caches"
        }
    }

    var subtitle: String {
        switch self {
        case .binary: "Standalone CLI tools installed on your PATH"
        case .homebrew: "Formulae, casks, and service data installed by Homebrew"
        case .nodeGlobal: "CLI tools installed globally via npm, bun, pnpm, or yarn"
        case .versionManager: "Language runtimes managed by per-tool version switchers"
        case .toolchain: "Compilers, runtimes, and globally installed CLI binaries"
        case .packageCache: "Re-downloadable package and bottle caches"
        }
    }
}

/// Maps scanned CLI roots (see `DependencyPaths.CLI`) to friendly descriptors.
enum CLIProgramCatalog {
    /// Build the program list for a set of CLI findings.
    ///
    /// Container roots (Homebrew Cellar/Caskroom, version-manager version dirs)
    /// are expanded into one program per installed item, so this reflects what is
    /// actually installed rather than collapsing everything into a few rows.
    /// Enumerates the filesystem — call off the main thread.
    static func programs(from findings: [StorageFinding]) -> [CLIProgram] {
        let urls = findings.flatMap(\.filePaths)
        return programs(from: urls)
    }

    static func programs(from urls: [URL]) -> [CLIProgram] {
        deduplicated(urls.flatMap(expand(root:)) + NodeGlobalCatalog.installedPrograms())
    }

    /// Discovers every installed CLI program directly from the filesystem,
    /// independent of the storage scan. This is what the CLI Programs screen uses,
    /// so Homebrew formulae/casks, version managers, global Node packages, and
    /// standalone installer binaries all appear without needing a scan first.
    /// Enumerates the filesystem — call off the main thread.
    static func discoverInstalled() -> [CLIProgram] {
        let fromRoots = canonicalRoots.flatMap(expand(root:))
        let nodeGlobals = NodeGlobalCatalog.installedPrograms()
        let npx = NodeGlobalCatalog.npxCachedPrograms()
        let binaries = InstalledBinaryCatalog.installedPrograms()
        return deduplicated(fromRoots + nodeGlobals + binaries + npx)
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    /// First occurrence of each URL wins; keeps the richer, source-ordered entry.
    private static func deduplicated(_ programs: [CLIProgram]) -> [CLIProgram] {
        var seen = Set<URL>()
        return programs.filter { seen.insert($0.url).inserted }
    }

    /// Canonical install locations probed regardless of scan state. Mirrors the
    /// roots in `DependencyPaths.CLI` but owned here so discovery is self-contained.
    static let canonicalRoots: [URL] = {
        let home = UserHomeDirectory.url
        func at(_ path: String) -> URL { home.appendingPathComponent(path) }
        return [
            // Homebrew (both Apple Silicon and Intel prefixes).
            URL(fileURLWithPath: "/opt/homebrew/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/Caskroom", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/var", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Caskroom", isDirectory: true),
            // Version managers.
            at(".nvm"), at(".volta"), at(".fnm"), at(".pyenv"), at(".rbenv"), at(".rvm"),
            // Toolchains & caches.
            at(".rustup"), at("Library/Caches/Homebrew")
        ]
    }()

    /// Expand a scanned root into one or more programs.
    static func expand(root: URL) -> [CLIProgram] {
        guard let container = container(for: root) else {
            return [descriptor(for: root)]
        }

        let children = container.children(under: root)
        guard !children.isEmpty else {
            // Container exists but we couldn't read children — keep the root row
            // so the storage is still represented.
            return [descriptor(for: root)]
        }

        return children.map { child in
            CLIProgram(
                url: child,
                displayName: child.lastPathComponent,
                subtitle: container.childSubtitle,
                symbolName: container.symbolName,
                accent: container.accent,
                category: container.category,
                safety: container.safety
            )
        }
    }

    /// Resolve a single root URL to a descriptor by matching its trailing path.
    static func descriptor(for url: URL) -> CLIProgram {
        if let template = template(for: url) {
            return CLIProgram(
                url: url,
                displayName: template.displayName,
                subtitle: template.subtitle,
                symbolName: template.symbolName,
                accent: template.accent,
                category: template.category,
                safety: template.safety
            )
        }

        // Fallback: derive a readable name from the last path component.
        return CLIProgram(
            url: url,
            displayName: fallbackName(for: url),
            subtitle: "Command-line tool data",
            symbolName: "terminal",
            accent: AppTheme.teal,
            category: .toolchain,
            safety: .review
        )
    }
}

// MARK: - Containers (roots that hold many installed programs)

extension CLIProgramCatalog {
    struct Container {
        /// Root path suffix this container matches (e.g. "/Cellar").
        let suffix: String
        /// Relative path under the root that holds the child items.
        /// Empty means the children live directly in the root.
        let childSubpath: String
        /// `true` when each installed item is a directory (formulae, versions);
        /// `false` when items are executable files (e.g. `bin` folders).
        let childrenAreDirectories: Bool
        let childSubtitle: String
        let symbolName: String
        let accent: Color
        let category: CLIProgramCategory
        let safety: CleanupSafety

        func children(under root: URL) -> [URL] {
            let base = childSubpath.isEmpty ? root : root.appendingPathComponent(childSubpath)
            let fileManager = FileManager.default
            guard let items = try? fileManager.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }

            return items
                .filter { url in
                    let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
                        ?? url.hasDirectoryPath
                    return isDirectory == childrenAreDirectories
                }
                .sorted {
                    $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
                }
        }
    }

    private static func container(for url: URL) -> Container? {
        let path = url.path
        return containers.first { path.hasSuffix($0.suffix) }
    }

    private static let containers: [Container] = [
        Container(
            suffix: "/Cellar",
            childSubpath: "",
            childrenAreDirectories: true,
            childSubtitle: "Homebrew formula",
            symbolName: "mug.fill",
            accent: AppTheme.orange,
            category: .homebrew,
            safety: .review
        ),
        Container(
            suffix: "/Caskroom",
            childSubpath: "",
            childrenAreDirectories: true,
            childSubtitle: "Homebrew cask",
            symbolName: "shippingbox.fill",
            accent: AppTheme.orange,
            category: .homebrew,
            safety: .review
        ),
        Container(
            suffix: "/.nvm",
            childSubpath: "versions/node",
            childrenAreDirectories: true,
            childSubtitle: "Node.js version (nvm)",
            symbolName: "arrow.triangle.branch",
            accent: AppTheme.mint,
            category: .versionManager,
            safety: .review
        ),
        Container(
            suffix: "/.volta",
            childSubpath: "tools/image/node",
            childrenAreDirectories: true,
            childSubtitle: "Node.js version (Volta)",
            symbolName: "bolt.fill",
            accent: AppTheme.mint,
            category: .versionManager,
            safety: .review
        ),
        Container(
            suffix: "/.pyenv",
            childSubpath: "versions",
            childrenAreDirectories: true,
            childSubtitle: "Python version (pyenv)",
            symbolName: "chevron.left.forwardslash.chevron.right",
            accent: AppTheme.cyan,
            category: .versionManager,
            safety: .review
        ),
        Container(
            suffix: "/.rbenv",
            childSubpath: "versions",
            childrenAreDirectories: true,
            childSubtitle: "Ruby version (rbenv)",
            symbolName: "diamond.fill",
            accent: AppTheme.rose,
            category: .versionManager,
            safety: .review
        ),
        Container(
            suffix: "/.rvm",
            childSubpath: "rubies",
            childrenAreDirectories: true,
            childSubtitle: "Ruby version (RVM)",
            symbolName: "diamond.fill",
            accent: AppTheme.rose,
            category: .versionManager,
            safety: .review
        ),
        Container(
            suffix: "/.cargo/bin",
            childSubpath: "",
            childrenAreDirectories: false,
            childSubtitle: "Installed Rust CLI binary",
            symbolName: "terminal.fill",
            accent: AppTheme.orange,
            category: .toolchain,
            safety: .review
        ),
        Container(
            suffix: "/.bun/bin",
            childSubpath: "",
            childrenAreDirectories: false,
            childSubtitle: "Installed Bun CLI binary",
            symbolName: "hare.fill",
            accent: AppTheme.indigo,
            category: .toolchain,
            safety: .review
        )
    ]
}

// MARK: - Matching

extension CLIProgramCatalog {
    private struct Template {
        let displayName: String
        let subtitle: String
        let symbolName: String
        let accent: Color
        let category: CLIProgramCategory
        let safety: CleanupSafety
    }

    /// Each rule matches when the URL's path ends with the given suffix.
    private static func template(for url: URL) -> Template? {
        let path = url.path
        for rule in rules where path.hasSuffix(rule.suffix) {
            return rule.template
        }
        return nil
    }

    private struct Rule {
        let suffix: String
        let template: Template
    }

    private static let rules: [Rule] = [
        // Homebrew
        Rule(
            suffix: "/Library/Caches/Homebrew",
            template: Template(
                displayName: "Homebrew cache",
                subtitle: "Downloaded formula bottles and casks",
                symbolName: "shippingbox",
                accent: AppTheme.orange,
                category: .homebrew,
                safety: .safe
            )
        ),
        Rule(
            suffix: "/Cellar",
            template: Template(
                displayName: "Homebrew formulae",
                subtitle: "Installed command-line packages",
                symbolName: "mug.fill",
                accent: AppTheme.orange,
                category: .homebrew,
                safety: .review
            )
        ),
        Rule(
            suffix: "/Caskroom",
            template: Template(
                displayName: "Homebrew casks",
                subtitle: "Installed cask applications and binaries",
                symbolName: "shippingbox.fill",
                accent: AppTheme.orange,
                category: .homebrew,
                safety: .review
            )
        ),
        Rule(
            suffix: "/opt/homebrew/var",
            template: Template(
                displayName: "Homebrew services data",
                subtitle: "Databases and running-service state",
                symbolName: "externaldrive.fill",
                accent: AppTheme.orange,
                category: .homebrew,
                safety: .review
            )
        ),
        // Version managers
        Rule(
            suffix: "/.nvm",
            template: Template(
                displayName: "nvm",
                subtitle: "Installed Node.js versions",
                symbolName: "arrow.triangle.branch",
                accent: AppTheme.mint,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.volta",
            template: Template(
                displayName: "Volta",
                subtitle: "Node.js toolchain manager",
                symbolName: "bolt.fill",
                accent: AppTheme.mint,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.fnm",
            template: Template(
                displayName: "fnm",
                subtitle: "Fast Node.js version manager",
                symbolName: "arrow.triangle.branch",
                accent: AppTheme.mint,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.pyenv",
            template: Template(
                displayName: "pyenv",
                subtitle: "Installed Python versions",
                symbolName: "chevron.left.forwardslash.chevron.right",
                accent: AppTheme.cyan,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.rbenv",
            template: Template(
                displayName: "rbenv",
                subtitle: "Installed Ruby versions",
                symbolName: "diamond.fill",
                accent: AppTheme.rose,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.rvm",
            template: Template(
                displayName: "RVM",
                subtitle: "Ruby versions and gemsets",
                symbolName: "diamond.fill",
                accent: AppTheme.rose,
                category: .versionManager,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.rustup",
            template: Template(
                displayName: "Rustup",
                subtitle: "Rust toolchains and components",
                symbolName: "gearshape.2.fill",
                accent: AppTheme.orange,
                category: .toolchain,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.cargo/bin",
            template: Template(
                displayName: "Cargo binaries",
                subtitle: "Installed Rust CLI tools",
                symbolName: "terminal.fill",
                accent: AppTheme.orange,
                category: .toolchain,
                safety: .review
            )
        ),
        Rule(
            suffix: "/.bun/bin",
            template: Template(
                displayName: "Bun",
                subtitle: "Bun runtime and global binaries",
                symbolName: "hare.fill",
                accent: AppTheme.indigo,
                category: .toolchain,
                safety: .review
            )
        )
    ]

    private static func fallbackName(for url: URL) -> String {
        let name = url.lastPathComponent
        guard name.hasPrefix(".") else { return name }
        return String(name.dropFirst())
    }
}
