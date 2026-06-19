import Foundation

enum CLIRemovalError: Error, LocalizedError, Equatable {
    case homebrewUninstallFailed(name: String, message: String)
    case nodeUninstallFailed(package: String, message: String)
    case removalFailed(URL, message: String)

    var errorDescription: String? {
        switch self {
        case let .homebrewUninstallFailed(name, message):
            "Couldn't uninstall \(name): \(message)"
        case let .nodeUninstallFailed(package, message):
            "Couldn't uninstall \(package): \(message)"
        case let .removalFailed(url, message):
            "Couldn't remove \(url.lastPathComponent): \(message)"
        }
    }
}

/// Removes CLI programs *properly*, without leaving abandoned files behind.
///
/// - Homebrew formulae and casks are removed with `brew uninstall`, which also
///   tears down the symlinks Homebrew created in `bin`, `opt`, `share`, etc. and
///   keeps Homebrew's own bookkeeping consistent. Trashing the keg directly would
///   leave those symlinks dangling and Homebrew believing the package is still
///   installed — exactly the orphaned state we want to avoid.
/// - Everything else (version-manager versions, toolchain dirs, installed binaries)
///   is moved to the Trash.
/// - After any Homebrew removal, a safety sweep deletes broken symlinks left in the
///   Homebrew link directories, covering anything a previous partial removal orphaned.
///
/// All side effects are injected so the logic is fully testable without touching the
/// real system. Use ``live`` for production.
struct CLIRemovalService: Sendable {
    struct CommandOutput: Sendable {
        let exitCode: Int32
        let output: String

        var succeeded: Bool { exitCode == 0 }
    }

    /// Absolute path to the `brew` executable, or nil when Homebrew isn't installed.
    var locateBrew: @Sendable () -> URL?
    /// Runs a command and returns its exit code and combined stdout/stderr.
    var runCommand: @Sendable (_ tool: URL, _ arguments: [String]) async -> CommandOutput
    /// Measures an item's on-disk size before it is removed.
    var measure: @Sendable (_ url: URL) -> Int64
    /// Moves an item to the Trash.
    var trashItem: @Sendable (_ url: URL) throws -> Void
    /// Directories swept for broken symlinks after a Homebrew removal.
    var homebrewLinkDirectories: @Sendable () -> [URL]
    /// Lists the immediate symlinks within a directory.
    var symlinks: @Sendable (_ directory: URL) -> [URL]
    /// True when a symlink's destination no longer exists (i.e. it is dangling).
    var isDangling: @Sendable (_ symlink: URL) -> Bool
    /// Permanently removes a broken symlink (it points to nothing, so this is safe).
    var removeSymlink: @Sendable (_ symlink: URL) throws -> Void
    /// True when a path is an existing executable file.
    var isExecutable: @Sendable (_ url: URL) -> Bool
    /// User `bin` directories swept for dangling PATH symlinks after any removal
    /// (e.g. `~/.local/bin/claude` left behind when a tool's install is deleted).
    var userBinDirectories: @Sendable () -> [URL]

    /// Accumulates the result of removing each program.
    private struct Outcome {
        var deletedItems: [DeletedItem] = []
        var deletedURLs: [URL] = []
        var failed: [(URL, Error)] = []
        /// Bin/link directories swept for dangling symlinks once removals finish.
        var directoriesToSweep: Set<URL> = []

        mutating func removed(_ url: URL, _ size: Int64) {
            deletedItems.append(DeletedItem(originalURL: url, bytesReclaimed: size))
            deletedURLs.append(url)
        }

        mutating func recordFailure(_ url: URL, _ error: Error) {
            failed.append((url, error))
        }
    }

    func remove(_ urls: [URL]) async -> CleanupResult {
        guard !urls.isEmpty else {
            return CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
        }

        let brew = locateBrew()
        var outcome = Outcome()

        for url in urls {
            switch Self.classify(url) {
            case let .homebrew(name, isCask):
                await removeHomebrew(url, name: name, isCask: isCask, brew: brew, into: &outcome)
            case let .nodeGlobal(plan):
                await removeNodeGlobal(url, plan: plan, into: &outcome)
            case .other:
                trash(url, into: &outcome)
            }
        }

        // Any removal can orphan a PATH symlink, so always sweep the user bin dirs.
        // The sweep only deletes already-dangling links, so this is safe.
        if !outcome.deletedURLs.isEmpty {
            outcome.directoriesToSweep.formUnion(userBinDirectories())
        }
        sweepBrokenSymlinks(in: outcome.directoriesToSweep)

        return CleanupResult(
            deletedURLs: outcome.deletedURLs,
            deletedItems: outcome.deletedItems,
            failedURLs: outcome.failed,
            totalBytesReclaimed: outcome.deletedItems.reduce(0) { $0 + $1.bytesReclaimed }
        )
    }

    private func removeHomebrew(
        _ url: URL,
        name: String,
        isCask: Bool,
        brew: URL?,
        into outcome: inout Outcome
    ) async {
        outcome.directoriesToSweep.formUnion(homebrewLinkDirectories())
        guard let brew else {
            // No Homebrew on this machine — fall back to trashing the keg.
            trash(url, into: &outcome)
            return
        }

        // Measure before uninstalling — the files are gone afterwards.
        let size = measure(url)
        let output = await runCommand(brew, ["uninstall", isCask ? "--cask" : "--formula", name])
        if output.succeeded {
            outcome.removed(url, size)
        } else {
            outcome.recordFailure(url, CLIRemovalError.homebrewUninstallFailed(
                name: name,
                message: Self.firstMeaningfulLine(of: output.output)
            ))
        }
    }

    private func removeNodeGlobal(
        _ url: URL,
        plan: NodeGlobalRemoval,
        into outcome: inout Outcome
    ) async {
        outcome.directoriesToSweep.insert(plan.binDirectory)
        guard let tool = plan.toolCandidates.first(where: isExecutable) else {
            // No package manager available — trash the package directory. npm keeps
            // no separate bookkeeping, so the bin sweep completes the removal cleanly.
            trash(url, into: &outcome)
            return
        }

        // Measure before uninstalling — the files are gone afterwards.
        let size = measure(url)
        let output = await runCommand(tool, plan.arguments)
        if output.succeeded {
            outcome.removed(url, size)
        } else {
            outcome.recordFailure(url, CLIRemovalError.nodeUninstallFailed(
                package: plan.packageName,
                message: Self.firstMeaningfulLine(of: output.output)
            ))
        }
    }

    private func trash(_ url: URL, into outcome: inout Outcome) {
        let size = measure(url)
        do {
            try trashItem(url)
            outcome.removed(url, size)
        } catch {
            outcome.recordFailure(url, error)
        }
    }

    private func sweepBrokenSymlinks(in directories: Set<URL>) {
        for directory in directories {
            for symlink in symlinks(directory) where isDangling(symlink) {
                try? removeSymlink(symlink)
            }
        }
    }

    private static func firstMeaningfulLine(of output: String) -> String {
        let line = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line ?? "The package manager reported an error."
    }
}

// MARK: - Classification

extension CLIRemovalService {
    enum ProgramKind: Equatable {
        case homebrew(name: String, isCask: Bool)
        case nodeGlobal(NodeGlobalRemoval)
        case other
    }

    /// How to properly uninstall a globally-installed Node package.
    struct NodeGlobalRemoval: Equatable {
        let packageName: String
        /// Candidate package-manager executables, tried in order.
        let toolCandidates: [URL]
        let arguments: [String]
        /// Directory whose dangling symlinks are swept after removal.
        let binDirectory: URL
    }

    /// Classifies a program URL so it can be removed by the right mechanism.
    static func classify(_ url: URL) -> ProgramKind {
        switch url.deletingLastPathComponent().lastPathComponent {
        case "Cellar":
            return .homebrew(name: url.lastPathComponent, isCask: false)
        case "Caskroom":
            return .homebrew(name: url.lastPathComponent, isCask: true)
        default:
            break
        }

        if let plan = nodeGlobalRemoval(for: url) {
            return .nodeGlobal(plan)
        }
        return .other
    }

    /// Builds an uninstall plan for a package that lives in a `node_modules` tree,
    /// inferring the package manager and its bin directory from the path.
    static func nodeGlobalRemoval(for url: URL) -> NodeGlobalRemoval? {
        guard let nodeModules = ancestor(of: url, named: "node_modules") else { return nil }

        let parentCount = nodeModules.pathComponents.count
        let components = url.pathComponents
        guard components.count > parentCount else { return nil }

        let first = components[parentCount]
        let packageName: String
        if first.hasPrefix("@"), components.count > parentCount + 1 {
            packageName = "\(first)/\(components[parentCount + 1])"
        } else {
            packageName = first
        }

        return managerPlan(nodeModules: nodeModules, packageName: packageName)
    }

    private static func managerPlan(nodeModules: URL, packageName: String) -> NodeGlobalRemoval {
        // bun — .../.bun/install/global/node_modules
        if let bunDir = ancestor(of: nodeModules, named: ".bun") {
            let bin = bunDir.appendingPathComponent("bin")
            return NodeGlobalRemoval(
                packageName: packageName,
                toolCandidates: [bin.appendingPathComponent("bun")],
                arguments: ["remove", "-g", packageName],
                binDirectory: bin
            )
        }

        // pnpm — shims live in the PNPM_HOME directory (named "pnpm").
        if let pnpmHome = ancestor(of: nodeModules, named: "pnpm") {
            return NodeGlobalRemoval(
                packageName: packageName,
                toolCandidates: [
                    pnpmHome.appendingPathComponent("pnpm"),
                    URL(fileURLWithPath: "/opt/homebrew/bin/pnpm"),
                    URL(fileURLWithPath: "/usr/local/bin/pnpm")
                ],
                arguments: ["remove", "-g", packageName],
                binDirectory: pnpmHome
            )
        }

        // yarn classic — global bin in ~/.yarn/bin
        if ancestor(of: nodeModules, named: "yarn") != nil {
            let yarnBin = homeDirectory(from: nodeModules)?.appendingPathComponent(".yarn/bin")
            var tools: [URL] = []
            if let yarnBin { tools.append(yarnBin.appendingPathComponent("yarn")) }
            tools += [
                URL(fileURLWithPath: "/opt/homebrew/bin/yarn"),
                URL(fileURLWithPath: "/usr/local/bin/yarn")
            ]
            return NodeGlobalRemoval(
                packageName: packageName,
                toolCandidates: tools,
                arguments: ["global", "remove", packageName],
                binDirectory: yarnBin ?? nodeModules.appendingPathComponent(".bin")
            )
        }

        // npm (and version-manager Node installs) — <prefix>/lib/node_modules
        let parent = nodeModules.deletingLastPathComponent()
        let prefix = parent.lastPathComponent == "lib" ? parent.deletingLastPathComponent() : parent
        let bin = prefix.appendingPathComponent("bin")
        return NodeGlobalRemoval(
            packageName: packageName,
            toolCandidates: [bin.appendingPathComponent("npm")],
            arguments: ["uninstall", "-g", packageName],
            binDirectory: bin
        )
    }

    /// Walks up from `url` and returns the nearest ancestor (inclusive) whose last
    /// path component equals `name`.
    private static func ancestor(of url: URL, named name: String) -> URL? {
        var current = url
        while current.pathComponents.count > 1 {
            if current.lastPathComponent == name { return current }
            current = current.deletingLastPathComponent()
        }
        return nil
    }

    /// Extracts `/Users/<name>` from an absolute path, when present.
    private static func homeDirectory(from url: URL) -> URL? {
        let components = url.pathComponents
        guard components.count >= 3, components[1] == "Users" else { return nil }
        return URL(fileURLWithPath: "/\(components[1])/\(components[2])")
    }
}

// MARK: - Live implementation

extension CLIRemovalService {
    static let live = CLIRemovalService(
        locateBrew: {
            let candidates = [
                URL(fileURLWithPath: "/opt/homebrew/bin/brew"),
                URL(fileURLWithPath: "/usr/local/bin/brew")
            ]
            return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
        },
        runCommand: { tool, arguments in
            await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = tool
                process.arguments = arguments

                var environment = ProcessInfo.processInfo.environment
                // Keep uninstall fast and side-effect free.
                environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                environment["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
                environment["HOMEBREW_NO_ENV_HINTS"] = "1"
                process.environment = environment

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    return CommandOutput(exitCode: -1, output: error.localizedDescription)
                }

                // Drain before waiting so a full pipe buffer can't deadlock the child.
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return CommandOutput(
                    exitCode: process.terminationStatus,
                    output: String(bytes: data, encoding: .utf8) ?? ""
                )
            }.value
        },
        measure: { StorageFormatting.itemSize(at: $0) },
        trashItem: { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        },
        homebrewLinkDirectories: {
            let prefixes = ["/opt/homebrew", "/usr/local"]
            let subdirectories = ["bin", "sbin", "opt", "lib", "etc"]
            let fileManager = FileManager.default
            return prefixes
                .flatMap { prefix in subdirectories.map { URL(fileURLWithPath: "\(prefix)/\($0)") } }
                .filter { fileManager.fileExists(atPath: $0.path) }
        },
        symlinks: { directory in
            let fileManager = FileManager.default
            guard let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: []
            ) else {
                return []
            }
            return entries.filter {
                (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
            }
        },
        isDangling: { symlink in
            let fileManager = FileManager.default
            guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: symlink.path) else {
                return false
            }
            let resolved = destination.hasPrefix("/")
                ? destination
                : symlink.deletingLastPathComponent().appendingPathComponent(destination).path
            return !fileManager.fileExists(atPath: resolved)
        },
        removeSymlink: { symlink in
            try FileManager.default.removeItem(at: symlink)
        },
        isExecutable: { FileManager.default.isExecutableFile(atPath: $0.path) },
        userBinDirectories: {
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser
            let candidates = [
                home.appendingPathComponent(".local/bin"),
                home.appendingPathComponent("bin"),
                home.appendingPathComponent(".bin"),
                home.appendingPathComponent("go/bin"),
                home.appendingPathComponent(".deno/bin"),
                home.appendingPathComponent(".cargo/bin"),
                home.appendingPathComponent(".bun/bin"),
                URL(fileURLWithPath: "/usr/local/bin")
            ]
            return candidates.filter { fileManager.fileExists(atPath: $0.path) }
        }
    )
}
