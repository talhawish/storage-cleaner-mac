import Foundation

/// Discovers globally-installed Node.js CLI programs (e.g. Claude Code, Codex,
/// Gemini CLI, opencode) across every package manager and version manager.
///
/// Global packages live in `lib/node_modules` directories that the storage
/// scanner doesn't enumerate, and there can be hundreds of them. Rather than
/// shelling out to `npm root -g` (slow Node startup, one process per manager),
/// the well-known global locations are probed directly on disk, including the
/// version-specific directories created by nvm, fnm, Volta, and `n`.
///
/// Only packages that expose a `bin` in their `package.json` are treated as
/// programs, which filters out plain libraries. Enumerates the filesystem — call
/// off the main thread.
enum NodeGlobalCatalog {
    static func installedPrograms() -> [CLIProgram] {
        let fileManager = FileManager.default
        var seenURLs = Set<URL>()
        var programs: [CLIProgram] = []

        for directory in globalNodeModulesDirectories() {
            for packageURL in packageDirectories(in: directory) {
                guard !seenURLs.contains(packageURL) else { continue }
                guard let info = NodePackageInfo.read(at: packageURL, fileManager: fileManager) else { continue }
                guard info.hasExecutable else { continue }
                guard !Self.internalPackages.contains(info.name) else { continue }

                seenURLs.insert(packageURL)
                programs.append(
                    CLIProgram(
                        url: packageURL,
                        displayName: info.name,
                        subtitle: info.subtitle,
                        symbolName: "shippingbox",
                        accent: AppTheme.mint,
                        category: .nodeGlobal,
                        safety: .review
                    )
                )
            }
        }

        return programs.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Node packages that ship with the runtime and shouldn't be offered for removal.
    private static let internalPackages: Set<String> = ["npm", "npx", "corepack"]

    // MARK: - npx caches

    /// Tools run (and cached) via `npx <pkg>` live under `~/.npm/_npx/<hash>/`, with
    /// the invoked package recorded in that hash's `package.json` dependencies. Each
    /// cache is a re-downloadable directory, so it's surfaced as a safe-to-clean item
    /// named after the tool it ran.
    static func npxCachedPrograms(root: URL? = nil) -> [CLIProgram] {
        let fileManager = FileManager.default
        let npxRoot = root ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".npm/_npx")

        return childDirectories(of: npxRoot).compactMap { cacheDirectory in
            guard let name = primaryDependency(in: cacheDirectory, fileManager: fileManager) else { return nil }
            return CLIProgram(
                url: cacheDirectory,
                displayName: name,
                subtitle: "Cached npx tool",
                symbolName: "shippingbox",
                accent: AppTheme.mint,
                category: .packageCache,
                safety: .safe
            )
        }
    }

    private static func primaryDependency(in cacheDirectory: URL, fileManager: FileManager) -> String? {
        let manifest = cacheDirectory.appendingPathComponent("package.json")
        guard
            let data = try? Data(contentsOf: manifest),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dependencies = object["dependencies"] as? [String: Any]
        else {
            return nil
        }
        return dependencies.keys.min()
    }

    // MARK: - Global location discovery

    static func globalNodeModulesDirectories() -> [URL] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        var candidates: [URL] = [
            // Homebrew / nodejs.org installer / common custom prefixes.
            URL(fileURLWithPath: "/opt/homebrew/lib/node_modules"),
            URL(fileURLWithPath: "/usr/local/lib/node_modules"),
            home.appendingPathComponent(".npm-global/lib/node_modules"),
            home.appendingPathComponent(".npm-packages/lib/node_modules"),
            home.appendingPathComponent(".local/lib/node_modules"),
            // bun / yarn classic.
            home.appendingPathComponent(".bun/install/global/node_modules"),
            home.appendingPathComponent(".config/yarn/global/node_modules"),
            home.appendingPathComponent(".yarn/global/node_modules")
        ]

        // pnpm keeps a numbered global store, e.g. ~/Library/pnpm/global/5/node_modules.
        candidates += numberedGlobalStores(under: home.appendingPathComponent("Library/pnpm/global"))
        candidates += numberedGlobalStores(under: home.appendingPathComponent(".local/share/pnpm/global"))

        // Per-version managers: append each installed version's node_modules.
        candidates += versionedNodeModules(
            under: home.appendingPathComponent(".nvm/versions/node"),
            suffix: "lib/node_modules"
        )
        candidates += versionedNodeModules(
            under: home.appendingPathComponent(".fnm/node-versions"),
            suffix: "installation/lib/node_modules"
        )
        candidates += versionedNodeModules(
            under: home.appendingPathComponent("Library/Application Support/fnm/node-versions"),
            suffix: "installation/lib/node_modules"
        )
        candidates += versionedNodeModules(
            under: home.appendingPathComponent(".volta/tools/image/node"),
            suffix: "lib/node_modules"
        )
        candidates += versionedNodeModules(
            under: URL(fileURLWithPath: "/usr/local/n/versions/node"),
            suffix: "lib/node_modules"
        )

        // Volta installs globals into a dedicated packages directory.
        candidates.append(home.appendingPathComponent(".volta/tools/image/packages"))

        return candidates.filter { isDirectory($0, fileManager: fileManager) }
    }

    private static func numberedGlobalStores(under base: URL) -> [URL] {
        childDirectories(of: base).map { $0.appendingPathComponent("node_modules") }
    }

    private static func versionedNodeModules(under base: URL, suffix: String) -> [URL] {
        childDirectories(of: base).map { $0.appendingPathComponent(suffix) }
    }

    // MARK: - Package enumeration

    /// Lists the top-level package directories in a `node_modules` folder,
    /// descending one level into `@scope` directories.
    static func packageDirectories(in nodeModules: URL) -> [URL] {
        var result: [URL] = []
        for entry in childDirectories(of: nodeModules) {
            let name = entry.lastPathComponent
            if name == ".bin" || name == ".cache" { continue }
            if name.hasPrefix("@") {
                result.append(contentsOf: childDirectories(of: entry))
            } else {
                result.append(entry)
            }
        }
        return result
    }

    // MARK: - Filesystem helpers

    private static func childDirectories(of url: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return entries.filter { isDirectory($0, fileManager: fileManager) }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}

/// The pieces of a `package.json` the catalog cares about.
struct NodePackageInfo {
    let name: String
    let description: String?
    let hasExecutable: Bool

    var subtitle: String {
        if let description, !description.isEmpty {
            return description
        }
        return "Global npm package"
    }

    static func read(at packageDirectory: URL, fileManager: FileManager) -> NodePackageInfo? {
        let manifestURL = packageDirectory.appendingPathComponent("package.json")
        guard
            let data = try? Data(contentsOf: manifestURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let name = (object["name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? packageDirectory.lastPathComponent

        return NodePackageInfo(
            name: name,
            description: object["description"] as? String,
            hasExecutable: hasExecutable(in: object)
        )
    }

    /// `bin` may be a string (single command) or an object (multiple commands).
    private static func hasExecutable(in manifest: [String: Any]) -> Bool {
        switch manifest["bin"] {
        case let value as String:
            !value.isEmpty
        case let value as [String: Any]:
            !value.isEmpty
        default:
            false
        }
    }
}
