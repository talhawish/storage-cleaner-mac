import Foundation

/// Discovers language runtimes that have **multiple versions installed side by side** so the
/// user can reclaim space by removing older ones.
///
/// The detector is data-driven: each install layout is described once (a manager root + how its
/// version directories are laid out) and new tools are added by extending the descriptor lists
/// below — no new control flow. Coverage today:
///
/// * Version managers — nvm, Volta, fnm (Node.js), pyenv (Python), rbenv & RVM (Ruby), rustup
///   (Rust), goenv & GVM (Go), local .NET SDK installs, Jabba/jEnv (Java), phpenv (PHP), GHCup
///   (Haskell), FVM (Flutter), and mise/rtx.
/// * Homebrew versioned formulae — `php@8.1` + `php@8.2`, `node` + `node@18`, `python@3.x`, …
/// * Hand-cloned SDKs — `~/development/flutter`, `~/flutter` (Flutter), and any number of
///   `~/.stack/programs/<arch>/ghc-<version>` (Haskell Stack) directories.
/// * Plugin managers — asdf (`~/.asdf/installs/<plugin>/*`) and SDKMAN (`~/.sdkman/candidates/*`).
/// * Bun & Deno — per-version toolchains under `~/.bun/install/install` and the versioned
///   binaries in `~/.deno/bin`.
/// * Laravel Herd — per-PHP-version install roots under `~/Library/Application Support/Herd/`.
/// * System JDKs — `/Library/Java/JavaVirtualMachines/*.jdk` (detected; removal is manual since
///   they are root-owned — see `VersionSource.requiresManualRemoval`).
///
/// Enumerates the filesystem — call off the main thread. Sizing is intentionally *not* done here
/// (it is slow); callers measure the returned items separately, as `RuntimeVersionsSection` does.
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

    /// Every runtime with two or more installed versions, sorted alphabetically by runtime title
    /// (stable, predictable). Single-version runtimes are omitted — there is nothing to clean up.
    static func discoverGroups(environment: Environment = .live) -> [RuntimeVersionGroup] {
        let collector = RuntimeVersionCollector()
        collector.addManagerDescriptors(home: environment.home)
        collector.addHomebrewFormulae(cellars: environment.homebrewCellars)
        collector.add(.java, .jvm, jdkItems(in: environment.jvmDirectory))
        collector.add(.php, .herd, herdPhpItems(home: environment.home))
        collector.add(.node, .bun, bunNodeItems(home: environment.home))
        collector.add(.deno, .denoBin, denoItems(home: environment.home))
        collector.add(.flutter, .flutterSdk, flutterSdks(home: environment.home))
        collector.add(.haskell, .stack, stackGhcInstalls(home: environment.home))
        collector.add(.scala, .homebrew, homebrewScalaCellars(cellars: environment.homebrewCellars))
        collector.addNestedRoots(home: environment.home)

        return collector.finalizeGroups()
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

/// Mutable accumulator used by `RuntimeVersionCatalog.discoverGroups` so the catalog
/// can stay declarative (data-driven descriptors) while sharing a single bucket
/// dictionary across the helper passes. Keeping the state in a class sidesteps
/// Swift's exclusivity rules around `inout` captured in nested closures.
private final class RuntimeVersionCollector {
    private struct Bucket {
        let runtime: DevRuntime
        let source: VersionSource
        var items: [RuntimeVersionItem] = []
    }

    private var buckets: [String: Bucket] = [:]

    func add(_ runtime: DevRuntime, _ source: VersionSource, _ items: [RuntimeVersionItem]) {
        guard !items.isEmpty else { return }
        let key = "\(runtime.rawValue).\(source.rawValue)"
        buckets[key, default: Bucket(runtime: runtime, source: source)].items.append(contentsOf: items)
    }

    func addManagerDescriptors(home: URL) {
        for descriptor in RuntimeVersionCatalog.managerDescriptors(home: home) {
            add(
                descriptor.runtime,
                descriptor.source,
                RuntimeVersionCatalog.versionItems(in: descriptor.base)
            )
        }
    }

    func addHomebrewFormulae(cellars: [URL]) {
        for (runtime, items) in RuntimeVersionCatalog.homebrewItems(cellars: cellars) {
            add(runtime, .homebrew, items)
        }
    }

    /// Each per-manager install root that follows the `<plugin>/<version>` layout. We probe every
    /// well-known location so the detector picks up user-side installs under both the modern
    /// (`~/.local/share/...`) and legacy (`~/.<tool>/...`) data homes.
    func addNestedRoots(home: URL) {
        let asdfRoots = [
            ".asdf/installs",
            ".asdf-vm/installs",
            ".local/share/asdf-vm/installs"
        ]
        for path in asdfRoots {
            for entry in RuntimeVersionCatalog.nestedItems(
                installsRoot: home.appendingPathComponent(path),
                pluginMap: RuntimeVersionCatalog.asdfPluginMap,
                source: .asdf
            ) {
                add(entry.runtime, .asdf, [entry.item])
            }
        }

        for entry in RuntimeVersionCatalog.nestedItems(
            installsRoot: home.appendingPathComponent(".sdkman/candidates"),
            pluginMap: RuntimeVersionCatalog.sdkmanCandidateMap,
            source: .sdkman
        ) {
            add(entry.runtime, .sdkman, [entry.item])
        }

        for path in [".local/share/mise/installs", ".local/share/rtx/installs"] {
            for entry in RuntimeVersionCatalog.nestedItems(
                installsRoot: home.appendingPathComponent(path),
                pluginMap: RuntimeVersionCatalog.misePluginMap,
                source: .mise
            ) {
                add(entry.runtime, .mise, [entry.item])
            }
        }
    }

    func finalizeGroups() -> [RuntimeVersionGroup] {
        buckets.values
            .map { bucket in
                RuntimeVersionGroup(
                    runtime: bucket.runtime,
                    source: bucket.source,
                    items: RuntimeVersionCatalog.finalizeItems(bucket.items)
                )
            }
            .filter { $0.items.count >= 2 }
            .sorted { lhs, rhs in
                lhs.runtime.title.localizedCaseInsensitiveCompare(rhs.runtime.title) == .orderedAscending
            }
    }
}

// MARK: - Manager descriptors

extension RuntimeVersionCatalog {
    /// A manager whose versions live as immediate subdirectories of a single `base` path.
    struct ManagerDescriptor {
        let runtime: DevRuntime
        let source: VersionSource
        let base: URL
    }

    static func managerDescriptors(home: URL) -> [ManagerDescriptor] {
        func at(_ path: String) -> URL { home.appendingPathComponent(path) }
        return [
            // Node.js
            ManagerDescriptor(runtime: .node, source: .nvm, base: at(".nvm/versions/node")),
            ManagerDescriptor(runtime: .node, source: .volta, base: at(".volta/tools/image/node")),
            ManagerDescriptor(runtime: .node, source: .fnm, base: at(".fnm/node-versions")),
            ManagerDescriptor(
                runtime: .node,
                source: .fnm,
                base: at("Library/Application Support/fnm/node-versions")
            ),
            // Python
            ManagerDescriptor(runtime: .python, source: .pyenv, base: at(".pyenv/versions")),
            // Ruby
            ManagerDescriptor(runtime: .ruby, source: .rbenv, base: at(".rbenv/versions")),
            ManagerDescriptor(runtime: .ruby, source: .rvm, base: at(".rvm/rubies")),
            // Rust
            ManagerDescriptor(runtime: .rust, source: .rustup, base: at(".rustup/toolchains")),
            // Go
            ManagerDescriptor(runtime: .golang, source: .goenv, base: at(".goenv/versions")),
            ManagerDescriptor(runtime: .golang, source: .gvm, base: at(".gvm/gos")),
            // .NET
            ManagerDescriptor(runtime: .dotnet, source: .dotnet, base: at(".dotnet/sdk")),
            ManagerDescriptor(runtime: .dotnet, source: .dotnet, base: at(".dotnet/x64/sdk")),
            // Java
            ManagerDescriptor(runtime: .java, source: .jabba, base: at(".jabba/jdk")),
            ManagerDescriptor(runtime: .java, source: .jenv, base: at(".jenv/versions")),
            // PHP
            ManagerDescriptor(runtime: .php, source: .phpenv, base: at(".phpenv/versions")),
            // Haskell — Stack keeps installs under `~/.stack/programs/<arch>/`
            // and ghcup keeps GHC toolchains under `~/.ghcup/ghc/<version>`.
            ManagerDescriptor(runtime: .haskell, source: .ghcup, base: at(".ghcup/ghc")),
            // Flutter — FVM keeps versions in `~/fvm/versions` (or `~/development/fvm/versions`).
            ManagerDescriptor(runtime: .flutter, source: .fvm, base: at("fvm/versions")),
            ManagerDescriptor(runtime: .flutter, source: .fvm, base: at("development/fvm/versions"))
            // Extension point: add new version managers here once their on-disk layout is confirmed
            // to be user-owned.
        ]
    }

    /// Maps an asdf plugin directory name to a runtime.
    static let asdfPluginMap: [String: DevRuntime] = [
        "nodejs": .node, "node": .node, "python": .python, "ruby": .ruby,
        "golang": .golang, "go": .golang, "rust": .rust, "java": .java, "kotlin": .kotlin,
        "php": .php, "elixir": .elixir, "erlang": .erlang, "perl": .perl,
        "dart": .dart, "deno": .deno, "bun": .bun, "dotnet-core": .dotnet,
        "crystal": .ruby, "scala": .scala, "scala-cli": .scala, "clojure": .scala,
        "haskell": .haskell, "ghc": .haskell, "stack": .haskell, "cabal": .haskell,
        "lua": .lua, "luaJIT": .lua, "luajit": .lua, "nim": .lua, "zig": .lua, "ocaml": .lua
    ]

    /// mise keeps installs in the same plugin/version shape as asdf. rtx was the previous name and
    /// used the same layout, so both roots can share this map.
    static let misePluginMap: [String: DevRuntime] = [
        "node": .node, "nodejs": .node, "python": .python, "ruby": .ruby,
        "go": .golang, "golang": .golang, "rust": .rust, "java": .java, "kotlin": .kotlin,
        "php": .php, "elixir": .elixir, "erlang": .erlang, "perl": .perl,
        "dart": .dart, "flutter": .flutter, "deno": .deno, "bun": .bun,
        "dotnet": .dotnet, "dotnet-core": .dotnet,
        "swift": .swift, "crystal": .lua, "scala": .scala, "scala-cli": .scala,
        "clojure": .scala, "haskell": .haskell, "ghc": .haskell, "stack": .haskell,
        "lua": .lua, "luajit": .lua, "zig": .lua
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
        "elixir": .elixir, "erlang": .erlang, "perl": .perl, "dart": .dart,
        "flutter": .flutter, "scala": .scala, "haskell-stack": .haskell, "ghc": .haskell,
        "lua": .lua, "luajit": .lua
    ]
}

// MARK: - Enumeration

extension RuntimeVersionCatalog {
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

    /// Laravel Herd stores per-PHP-version install roots under
    /// `~/Library/Application Support/Herd/config/php/<version>` (legacy) or
    /// `~/Library/Application Support/Herd/bin/php/<version>` (current). Each
    /// subdirectory whose name parses as a `VersionKey` is treated as a PHP install.
    static func herdPhpItems(home: URL) -> [RuntimeVersionItem] {
        let support = home.appendingPathComponent(
            "Library/Application Support/Herd",
            isDirectory: true
        )
        let candidates = [
            support.appendingPathComponent("config/php", isDirectory: true),
            support.appendingPathComponent("bin/php", isDirectory: true),
            support.appendingPathComponent("Php", isDirectory: true)
        ]
        var items: [RuntimeVersionItem] = []
        for directory in candidates {
            for sub in subdirectories(of: directory)
                where VersionKey.parse(sub.lastPathComponent).numbers.isEmpty == false {
                items.append(item(url: sub, label: sub.lastPathComponent))
            }
        }
        return items
    }

    /// Bun's `bun --version` doesn't have a multi-root manager of its own, but the
    /// `~/.bun/install/cache` (downloads) and per-version toolchain directories under
    /// `~/.bun/install/install/<version>` can balloon in size. Older toolchains under
    /// `~/.bun/install/install` are surfaced when 2+ exist.
    static func bunNodeItems(home: URL) -> [RuntimeVersionItem] {
        let installRoot = home.appendingPathComponent(".bun/install/install", isDirectory: true)
        return subdirectories(of: installRoot)
            .filter { VersionKey.parse($0.lastPathComponent).numbers.isEmpty == false }
            .map { item(url: $0, label: $0.lastPathComponent) }
    }

    /// Deno's per-version installations live under `~/.deno/bin`. When multiple
    /// versioned binaries are present (e.g. from past upgrades), older copies are
    /// flagged.
    static func denoItems(home: URL) -> [RuntimeVersionItem] {
        let denoBin = home.appendingPathComponent(".deno/bin", isDirectory: true)
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: denoBin,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.compactMap { entry -> RuntimeVersionItem? in
            let name = entry.lastPathComponent
            guard name.hasPrefix("deno-") else { return nil }
            // Extract the version segment: `deno-1.45.5` → `1.45.5`.
            let label = String(name.dropFirst("deno-".count))
            return item(url: entry, label: label)
        }
    }

    /// Flutter SDK installs (separate from FVM). Users sometimes hand-clone the SDK
    /// to `~/development/flutter`, `~/flutter`, or a custom `FLUTTER_ROOT`. Each
    /// such clone is treated as one install; if the user keeps more than one
    /// (e.g. a pinned `stable` and a `master` for a project), older ones are
    /// surfaced. We dedupe by `VersionKey` so two clones of the same version
    /// (one stable, one dev) are merged.
    static func flutterSdks(home: URL) -> [RuntimeVersionItem] {
        let candidates = [
            home.appendingPathComponent("development/flutter", isDirectory: true),
            home.appendingPathComponent("flutter", isDirectory: true),
            home.appendingPathComponent("dev/flutter", isDirectory: true),
            home.appendingPathComponent("code/flutter", isDirectory: true),
            home.appendingPathComponent("src/flutter", isDirectory: true)
        ]
        var seen = Set<String>()
        var items: [RuntimeVersionItem] = []
        for root in candidates {
            let binFlutter = root.appendingPathComponent("bin/flutter", isDirectory: false)
            guard FileManager.default.isExecutableFile(atPath: binFlutter.path) else { continue }
            let version = flutterVersionLabel(at: root) ?? root.lastPathComponent
            guard seen.insert(version).inserted else { continue }
            items.append(item(url: root, label: version))
        }
        return items
    }

    /// `flutter --version` is the canonical way to read the SDK version, but it shells
    /// out to Dart — too slow for a scan. As a heuristic we read the
    /// `bin/internal/engine.version` (the engine) or the `version` file at the SDK
    /// root and fall back to the directory name.
    private static func flutterVersionLabel(at root: URL) -> String? {
        let candidates = [
            root.appendingPathComponent("version"),
            root.appendingPathComponent("bin/internal/engine.version"),
            root.appendingPathComponent("bin/cache/flutter.version.json")
        ]
        for path in candidates {
            if let text = try? String(contentsOf: path, encoding: .utf8) {
                if let line = text.split(whereSeparator: \.isNewline).first.map(String.init) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    /// Haskell Stack keeps one snapshot of every GHC version it has used under
    /// `~/.stack/programs/<arch>/ghc-<version>/` (e.g. `x86_64-osx/ghc-9.4.7`).
    /// Group by the GHC version (drop the arch prefix) so a single install is
    /// not double-counted across machine architectures.
    static func stackGhcInstalls(home: URL) -> [RuntimeVersionItem] {
        let programs = home.appendingPathComponent(".stack/programs", isDirectory: true)
        var seen = Set<String>()
        var items: [RuntimeVersionItem] = []
        for arch in subdirectories(of: programs) {
            for ghc in subdirectories(of: arch) {
                let name = ghc.lastPathComponent
                guard name.hasPrefix("ghc-") else { continue }
                let version = String(name.dropFirst("ghc-".count))
                let key = "ghc-\(version)"
                guard seen.insert(key).inserted else { continue }
                items.append(item(url: ghc, label: version))
            }
        }
        return items
    }

    /// Homebrew's Cellar is grouped by formula name above, so a Scala install appears
    /// as a single `.scala` slot (one keg per formula) with no version sub-dirs.
    /// Scala via Homebrew is a single version per keg, so this is mostly a
    /// placeholder for when scala-cli or `coursier` show up later. We still surface
    /// any Cellar formula that is itself a versioned `scala@<x>` so multiple
    /// install roots become visible.
    static func homebrewScalaCellars(cellars: [URL]) -> [RuntimeVersionItem] {
        var items: [RuntimeVersionItem] = []
        for cellar in cellars {
            for formula in subdirectories(of: cellar) {
                let name = formula.lastPathComponent
                if name.lowercased().hasPrefix("scala@") {
                    let label = String(name.dropFirst("scala@".count))
                    items.append(item(url: formula, label: label))
                }
            }
        }
        return items
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
        RuntimeVersionGroup(
            runtime: runtime,
            source: source,
            items: finalizeItems(items)
        )
    }

    /// Dedupes by URL, sorts newest → oldest, and marks the first (newest) item as the keep.
    /// Exposed separately so the discovery collector can hand finalized items to a fresh
    /// `RuntimeVersionGroup` after accumulating them.
    static func finalizeItems(_ items: [RuntimeVersionItem]) -> [RuntimeVersionItem] {
        var seen = Set<URL>()
        var unique = items
            .filter { seen.insert($0.url).inserted }
            .sorted { $0.key > $1.key }
        if !unique.isEmpty {
            unique[0].isNewest = true
        }
        return unique
    }
}
