import Foundation

/// Discovers language runtimes that have **multiple versions installed side by side** so the
/// user can reclaim space by removing older ones.
///
/// The detector is data-driven: each install layout is described once (a manager root + how its
/// version directories are laid out) and new tools are added by extending the descriptor lists
/// below — no new control flow. Coverage today:
///
/// * Version managers — nvm, Volta, fnm (Node), pyenv (Python), rbenv & RVM (Ruby), rustup (Rust),
///   goenv & GVM (Go), local .NET SDK installs, Jabba/jEnv (Java), and mise/rtx.
/// * Homebrew versioned formulae — `php@8.1` + `php@8.2`, `node` + `node@18`, `python@3.x`, …
/// * Plugin managers — asdf (`~/.asdf/installs/<plugin>/*`) and SDKMAN (`~/.sdkman/candidates/*`).
/// * System JDKs — `/Library/Java/JavaVirtualMachines/*.jdk` (detected; removal is manual since
///   they are root-owned — see `VersionSource.requiresManualRemoval`).
///
/// Enumerates the filesystem — call off the main thread. Sizing is intentionally *not* done here
/// (it is slow); callers measure the returned items separately, as `CLIProgramsView` does.
enum RuntimeVersionCatalog {
    /// Injectable filesystem roots so detection can be exercised against temp directories in tests.
    struct Environment: Sendable {
        var home: URL
        var homebrewCellars: [URL]
        var jvmDirectory: URL

        static var live: Environment {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return Environment(
                home: home,
                homebrewCellars: [
                    URL(fileURLWithPath: "/opt/homebrew/Cellar", isDirectory: true),
                    URL(fileURLWithPath: "/usr/local/Cellar", isDirectory: true)
                ],
                jvmDirectory: URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines", isDirectory: true)
            )
        }
    }

    /// Accumulates the versions discovered for one runtime+source while scanning.
    private struct Bucket {
        let runtime: DevRuntime
        let source: VersionSource
        var items: [RuntimeVersionItem] = []
    }

    /// Every runtime with two or more installed versions, sorted with the largest reclaimable
    /// total first. Single-version runtimes are omitted — there is nothing to clean up.
    static func discoverGroups(environment: Environment = .live) -> [RuntimeVersionGroup] {
        var buckets: [String: Bucket] = [:]

        func add(_ runtime: DevRuntime, _ source: VersionSource, _ items: [RuntimeVersionItem]) {
            guard !items.isEmpty else { return }
            let key = "\(runtime.rawValue).\(source.rawValue)"
            buckets[key, default: Bucket(runtime: runtime, source: source)].items.append(contentsOf: items)
        }

        for descriptor in managerDescriptors(home: environment.home) {
            add(descriptor.runtime, descriptor.source, versionItems(in: descriptor.base))
        }
        for (runtime, items) in homebrewItems(cellars: environment.homebrewCellars) {
            add(runtime, .homebrew, items)
        }
        add(.java, .jvm, jdkItems(in: environment.jvmDirectory))
        for entry in nestedItems(
            installsRoot: environment.home.appendingPathComponent(".asdf/installs"),
            pluginMap: asdfPluginMap,
            source: .asdf
        ) {
            add(entry.runtime, .asdf, [entry.item])
        }
        for entry in nestedItems(
            installsRoot: environment.home.appendingPathComponent(".sdkman/candidates"),
            pluginMap: sdkmanCandidateMap,
            source: .sdkman
        ) {
            add(entry.runtime, .sdkman, [entry.item])
        }
        for entry in nestedItems(
            installsRoot: environment.home.appendingPathComponent(".local/share/mise/installs"),
            pluginMap: misePluginMap,
            source: .mise
        ) {
            add(entry.runtime, .mise, [entry.item])
        }
        for entry in nestedItems(
            installsRoot: environment.home.appendingPathComponent(".local/share/rtx/installs"),
            pluginMap: misePluginMap,
            source: .mise
        ) {
            add(entry.runtime, .mise, [entry.item])
        }

        return buckets.values
            .map { finalize(runtime: $0.runtime, source: $0.source, items: $0.items) }
            .filter { $0.items.count >= 2 }
            .sorted { lhs, rhs in
                lhs.runtime.title.localizedCaseInsensitiveCompare(rhs.runtime.title) == .orderedAscending
            }
    }

    /// Fills in the on-disk size of every item. Used by the scanner so the Overview reflects the
    /// reclaimable total; the dedicated screen sizes lazily on its own.
    static func measured(_ groups: [RuntimeVersionGroup]) -> [RuntimeVersionGroup] {
        groups.map { group in
            let measured = group.items.map { item -> RuntimeVersionItem in
                var copy = item
                copy.bytes = StorageFormatting.itemSize(at: item.url)
                return copy
            }
            return RuntimeVersionGroup(runtime: group.runtime, source: group.source, items: measured)
        }
    }
}

// MARK: - Manager descriptors

private extension RuntimeVersionCatalog {
    /// A manager whose versions live as immediate subdirectories of a single `base` path.
    struct ManagerDescriptor {
        let runtime: DevRuntime
        let source: VersionSource
        let base: URL
    }

    static func managerDescriptors(home: URL) -> [ManagerDescriptor] {
        func at(_ path: String) -> URL { home.appendingPathComponent(path) }
        return [
            ManagerDescriptor(runtime: .node, source: .nvm, base: at(".nvm/versions/node")),
            ManagerDescriptor(runtime: .node, source: .volta, base: at(".volta/tools/image/node")),
            ManagerDescriptor(runtime: .node, source: .fnm, base: at(".fnm/node-versions")),
            ManagerDescriptor(
                runtime: .node,
                source: .fnm,
                base: at("Library/Application Support/fnm/node-versions")
            ),
            ManagerDescriptor(runtime: .python, source: .pyenv, base: at(".pyenv/versions")),
            ManagerDescriptor(runtime: .ruby, source: .rbenv, base: at(".rbenv/versions")),
            ManagerDescriptor(runtime: .ruby, source: .rvm, base: at(".rvm/rubies")),
            ManagerDescriptor(runtime: .rust, source: .rustup, base: at(".rustup/toolchains")),
            ManagerDescriptor(runtime: .golang, source: .goenv, base: at(".goenv/versions")),
            ManagerDescriptor(runtime: .golang, source: .gvm, base: at(".gvm/gos")),
            ManagerDescriptor(runtime: .dotnet, source: .dotnet, base: at(".dotnet/sdk")),
            ManagerDescriptor(runtime: .java, source: .jabba, base: at(".jabba/jdk")),
            ManagerDescriptor(runtime: .java, source: .jenv, base: at(".jenv/versions"))
            // Extension point: add new version managers here once their on-disk layout is confirmed
            // to be user-owned.
        ]
    }

    /// Maps an asdf plugin directory name to a runtime.
    static let asdfPluginMap: [String: DevRuntime] = [
        "nodejs": .node, "node": .node, "python": .python, "ruby": .ruby,
        "golang": .golang, "go": .golang, "rust": .rust, "java": .java, "kotlin": .kotlin,
        "php": .php, "elixir": .elixir, "erlang": .erlang, "perl": .perl,
        "dart": .dart, "deno": .deno, "bun": .bun, "dotnet-core": .dotnet
    ]

    /// mise keeps installs in the same plugin/version shape as asdf. rtx was the previous name and
    /// used the same layout, so both roots can share this map.
    static let misePluginMap: [String: DevRuntime] = [
        "node": .node, "nodejs": .node, "python": .python, "ruby": .ruby,
        "go": .golang, "golang": .golang, "rust": .rust, "java": .java, "kotlin": .kotlin,
        "php": .php, "elixir": .elixir, "erlang": .erlang, "perl": .perl,
        "dart": .dart, "deno": .deno, "bun": .bun, "dotnet": .dotnet, "dotnet-core": .dotnet,
        "swift": .swift
    ]

    /// Maps a SDKMAN candidate directory name to a runtime (build tools like gradle/maven are
    /// intentionally excluded — they are not language runtimes).
    static let sdkmanCandidateMap: [String: DevRuntime] = [
        "java": .java, "kotlin": .kotlin
    ]

    /// Maps a Homebrew formula's base name (before any `@version`) to a runtime.
    static let homebrewBaseRuntime: [String: DevRuntime] = [
        "php": .php, "node": .node, "python": .python, "ruby": .ruby, "go": .golang,
        "rust": .rust, "openjdk": .java, "kotlin": .kotlin, "deno": .deno, "bun": .bun,
        "elixir": .elixir, "erlang": .erlang, "perl": .perl, "dart": .dart
    ]
}

// MARK: - Enumeration

private extension RuntimeVersionCatalog {
    static func versionItems(in base: URL) -> [RuntimeVersionItem] {
        subdirectories(of: base).map { item(url: $0, label: $0.lastPathComponent) }
    }

    static func homebrewItems(cellars: [URL]) -> [(runtime: DevRuntime, items: [RuntimeVersionItem])] {
        var byRuntime: [DevRuntime: [RuntimeVersionItem]] = [:]
        for cellar in cellars {
            for formula in subdirectories(of: cellar) {
                let name = formula.lastPathComponent                 // "php@8.1" or "node"
                let base = name.split(separator: "@").first.map(String.init) ?? name
                guard let runtime = homebrewBaseRuntime[base.lowercased()] else { continue }
                let label = highestInnerVersion(in: formula)
                    ?? name.split(separator: "@").dropFirst().first.map(String.init)
                    ?? name
                byRuntime[runtime, default: []].append(item(url: formula, label: label))
            }
        }
        return byRuntime.map { ($0.key, $0.value) }
    }

    static func jdkItems(in directory: URL) -> [RuntimeVersionItem] {
        subdirectories(of: directory)
            .filter { $0.pathExtension == "jdk" }
            .map { item(url: $0, label: $0.deletingPathExtension().lastPathComponent) }
    }

    static func nestedItems(
        installsRoot: URL,
        pluginMap: [String: DevRuntime],
        source: VersionSource
    ) -> [(runtime: DevRuntime, item: RuntimeVersionItem)] {
        var result: [(runtime: DevRuntime, item: RuntimeVersionItem)] = []
        for plugin in subdirectories(of: installsRoot) {
            guard let runtime = pluginMap[plugin.lastPathComponent.lowercased()] else { continue }
            for version in subdirectories(of: plugin) {
                result.append((runtime, item(url: version, label: version.lastPathComponent)))
            }
        }
        return result
    }

    static func item(url: URL, label: String) -> RuntimeVersionItem {
        RuntimeVersionItem(url: url, versionLabel: label, key: VersionKey.parse(label), bytes: 0, isNewest: false)
    }

    /// Highest version subdirectory name inside a Homebrew keg (`Cellar/<formula>/<version>`).
    static func highestInnerVersion(in formula: URL) -> String? {
        subdirectories(of: formula)
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix(".") }
            .max { VersionKey.parse($0) < VersionKey.parse($1) }
    }

    /// Immediate real subdirectories of `base`, excluding hidden entries and symlinks (managers
    /// keep aliases like `default`/`current` as symlinks, which must not be counted as versions).
    static func subdirectories(of base: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDirectory = values?.isDirectory ?? url.hasDirectoryPath
            let isSymlink = values?.isSymbolicLink ?? false
            return isDirectory && !isSymlink
        }
    }

    /// Dedupes by URL, sorts newest → oldest, and marks the first (newest) item as the keep.
    static func finalize(
        runtime: DevRuntime,
        source: VersionSource,
        items: [RuntimeVersionItem]
    ) -> RuntimeVersionGroup {
        var seen = Set<URL>()
        var unique = items
            .filter { seen.insert($0.url).inserted }
            .sorted { $0.key > $1.key }
        if !unique.isEmpty {
            unique[0].isNewest = true
        }
        return RuntimeVersionGroup(runtime: runtime, source: source, items: unique)
    }
}
