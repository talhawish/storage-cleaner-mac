import Foundation

/// Discovers standalone CLI tools installed by curl/native installers and language
/// toolchains — the binaries that live in `bin` directories on the user's PATH
/// rather than in a package manager's store.
///
/// Examples this catches: Claude Code (`~/.local/bin/claude` → a versioned install),
/// opencode (`~/.opencode/bin/opencode`), and everything in `~/.cargo/bin`,
/// `~/go/bin`, `~/.deno/bin`, etc. Entries that resolve into Homebrew's Cellar or a
/// `node_modules` tree are skipped, since those are reported by their own catalogs.
///
/// Enumerates the filesystem and resolves symlinks — call off the main thread.
enum InstalledBinaryCatalog {
    static func installedPrograms(in directories: [URL] = binDirectories()) -> [CLIProgram] {
        let fileManager = FileManager.default
        var seen = Set<URL>()
        var programs: [CLIProgram] = []

        for directory in directories {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isSymbolicLinkKey, .isExecutableKey, .isDirectoryKey],
                options: []
            ) else {
                continue
            }

            for entry in entries {
                guard let resolved = resolvedTarget(of: entry, fileManager: fileManager) else { continue }
                let path = resolved.path
                // Counted by the Homebrew / Node-global catalogs already.
                if path.contains("/Cellar/") || path.contains("/node_modules/") { continue }
                guard seen.insert(resolved).inserted else { continue }

                programs.append(
                    CLIProgram(
                        url: resolved,
                        displayName: entry.lastPathComponent,
                        subtitle: "Installed CLI tool",
                        symbolName: "terminal",
                        accent: AppTheme.teal,
                        category: .binary,
                        safety: .review
                    )
                )
            }
        }

        return programs.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Resolves a bin entry to the real install it represents, or nil if it isn't a
    /// program (non-executable file, directory, or a dangling symlink).
    private static func resolvedTarget(of entry: URL, fileManager: FileManager) -> URL? {
        let values = try? entry.resourceValues(forKeys: [.isSymbolicLinkKey, .isExecutableKey, .isDirectoryKey])

        if values?.isSymbolicLink == true {
            let resolved = entry.resolvingSymlinksInPath()
            guard fileManager.fileExists(atPath: resolved.path) else { return nil } // dangling
            return resolved
        }

        // A real executable file (skip directories and plain data files).
        if values?.isExecutable == true, values?.isDirectory != true {
            return entry.resolvingSymlinksInPath()
        }

        return nil
    }

    // MARK: - Bin directory discovery

    static func binDirectories() -> [URL] {
        let fileManager = FileManager.default
        let home = UserHomeDirectory.url
        func at(_ path: String) -> URL { home.appendingPathComponent(path) }

        var directories: [URL] = [
            at(".local/bin"),
            at("bin"),
            at(".bin"),
            at("go/bin"),
            at(".deno/bin"),
            at(".cargo/bin"),
            at(".bun/bin"),
            at(".npm-global/bin"),
            at(".npm-packages/bin"),
            at(".yarn/bin"),
            at(".config/yarn/bin"),
            at(".local/share/pnpm"),
            URL(fileURLWithPath: "/usr/local/bin")
        ]

        // Tool-specific homes like ~/.opencode/bin, ~/.foundry/bin, ~/.rye/shims.
        directories += autodiscoveredToolBins(home: home, fileManager: fileManager)

        var seen = Set<URL>()
        return directories.filter {
            isDirectory($0, fileManager: fileManager) && seen.insert($0.standardizedFileURL).inserted
        }
    }

    /// Internal for testing — do not call directly from outside this file.
    static func autodiscoveredToolBins(home: URL, fileManager: FileManager) -> [URL] {
        // Keep known tool bin directories as a fallback when the home
        // directory cannot be enumerated (sandboxed build without active
        // security-scoped access). These are merged with autodiscovered
        // entries so they are still found regardless of scope state.
        let known = knownToolBins(home: home, fileManager: fileManager)

        guard let entries = try? fileManager.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            return known
        }

        let autodiscovered = entries
            .filter { $0.lastPathComponent.hasPrefix(".") && isDirectory($0, fileManager: fileManager) }
            .map { $0.appendingPathComponent("bin") }
            .filter { isDirectory($0, fileManager: fileManager) }

        return autodiscovered + known
    }

    /// Well-known tool-specific bin directories that autodiscovery would
    /// normally find by enumerating home, listed explicitly so they are
    /// still probed when security-scoped access has not been granted.
    /// When home enumeration succeeds these are still included (and
    /// deduplicated by the caller) as a safety net.
    private static func knownToolBins(home: URL, fileManager: FileManager) -> [URL] {
        let candidates = [
            ".opencode/bin",
            ".foundry/bin",
            ".rye/shims"
        ]
        return candidates
            .map { home.appendingPathComponent($0) }
            .filter { isDirectory($0, fileManager: fileManager) }
    }

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
}
