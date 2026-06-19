import Foundation

/// Discovers and removes simulator/emulator **OS images** — the biggest space hogs in a developer's
/// toolchain (an Apple runtime is often 8+ GB; Android system images run several GB per API level).
///
/// Removal is the safest mechanism per platform:
/// * Apple simulator runtimes live under SIP-protected `/System/Library/AssetsV2`, so they are removed
///   with `xcrun simctl runtime delete` (permanent, but re-downloadable from Apple).
/// * Android system images are user-owned folders, so they are moved to the Trash (restorable).
///
/// All side effects are injected so the logic is fully testable without touching the real system —
/// use ``live`` for production. Discovery enumerates the filesystem and runs a subprocess; call it off
/// the main thread.
struct EmulatorManagementService: Sendable {
    struct CommandOutput: Sendable {
        let exitCode: Int32
        let output: String
        var succeeded: Bool { exitCode == 0 }
    }

    /// Runs a command and returns its exit code and combined stdout/stderr.
    var runCommand: @Sendable (_ tool: URL, _ arguments: [String]) async -> CommandOutput
    /// Absolute path to `xcrun`, or nil when the Xcode command-line tools are unavailable.
    var locateXcrun: @Sendable () -> URL?
    /// Root of the Android `system-images` directory, or nil when no SDK is installed.
    var androidSystemImagesRoot: @Sendable () -> URL?
    /// Measures an item's on-disk size.
    var measure: @Sendable (_ url: URL) -> Int64
    /// Moves an item to the Trash.
    var trashItem: @Sendable (_ url: URL) throws -> Void

    // MARK: - Discovery

    /// Every installed OS image, sorted by platform then newest → oldest. Apple sizes come from
    /// simctl (instant); Android images are returned with `bytes == 0` and sized separately via
    /// ``measuringAndroidSizes(in:)`` so the list can appear immediately.
    func discover() async -> [EmulatorImage] {
        let apple = await discoverAppleRuntimes()
        let android = discoverAndroidImages()
        return (apple + android).sorted { lhs, rhs in
            if lhs.platform.sortIndex != rhs.platform.sortIndex {
                return lhs.platform.sortIndex < rhs.platform.sortIndex
            }
            return lhs.key > rhs.key
        }
    }

    /// Returns `images` with Android entries' on-disk sizes filled in (Apple sizes are already known).
    func measuringAndroidSizes(in images: [EmulatorImage]) -> [EmulatorImage] {
        images.map { image in
            guard case let .trashDirectory(url) = image.removal else { return image }
            var copy = image
            copy.bytes = measure(url)
            return copy
        }
    }

    private func discoverAppleRuntimes() async -> [EmulatorImage] {
        guard let xcrun = locateXcrun() else { return [] }
        let output = await runCommand(xcrun, ["simctl", "runtime", "list", "-j"])
        guard output.succeeded, let data = output.output.data(using: .utf8) else { return [] }
        guard let decoded = try? JSONDecoder().decode([String: RuntimeJSON].self, from: data) else { return [] }

        let isoFormatter = ISO8601DateFormatter()
        let relativeFormatter = RelativeDateTimeFormatter()
        let referenceDate = Date()

        return decoded.values.map { runtime in
            let platformName = Self.applePlatformName(
                platformIdentifier: runtime.platformIdentifier,
                runtimeIdentifier: runtime.runtimeIdentifier
            )
            let version = runtime.version ?? "Unknown"
            let lastUsed = runtime.lastUsedAt.flatMap(isoFormatter.date(from:))
            var detail = "Build \(runtime.build ?? "—")"
            if let lastUsed {
                detail += " · last used \(relativeFormatter.localizedString(for: lastUsed, relativeTo: referenceDate))"
            }

            return EmulatorImage(
                id: runtime.identifier,
                platform: .appleSimulator,
                title: "\(platformName) \(version)",
                versionLabel: version,
                key: VersionKey.parse(version),
                bytes: runtime.sizeBytes ?? 0,
                detail: detail,
                removal: .simctlRuntime(identifier: runtime.identifier),
                isRemovable: runtime.deletable,
                lastUsed: lastUsed
            )
        }
    }

    private func discoverAndroidImages() -> [EmulatorImage] {
        guard let root = androidSystemImagesRoot() else { return [] }
        var images: [EmulatorImage] = []

        for apiDir in Self.subdirectories(of: root) {
            let apiLabel = Self.androidAPILabel(from: apiDir.lastPathComponent)
            for tagDir in Self.subdirectories(of: apiDir) {
                for abiDir in Self.subdirectories(of: tagDir) {
                    let tag = tagDir.lastPathComponent
                    let abi = abiDir.lastPathComponent
                    images.append(
                        EmulatorImage(
                            id: abiDir.path,
                            platform: .androidEmulator,
                            title: "Android \(apiLabel) · \(tag) · \(abi)",
                            versionLabel: apiLabel,
                            key: VersionKey.parse(apiLabel),
                            bytes: 0,
                            detail: "\(tag) · \(abi)",
                            removal: .trashDirectory(abiDir),
                            isRemovable: true,
                            lastUsed: nil
                        )
                    )
                }
            }
        }
        return images
    }

    // MARK: - Removal

    func remove(_ images: [EmulatorImage]) async -> EmulatorCleanupResult {
        var removedIDs: [String] = []
        var reclaimed: Int64 = 0
        var failures: [EmulatorCleanupResult.Failure] = []

        let xcrun = locateXcrun()
        for image in images where image.isRemovable {
            switch image.removal {
            case let .simctlRuntime(identifier):
                guard let xcrun else {
                    failures.append(.init(id: image.id, message: "Xcode command-line tools not found."))
                    continue
                }
                let output = await runCommand(xcrun, ["simctl", "runtime", "delete", identifier])
                if output.succeeded {
                    removedIDs.append(image.id)
                    reclaimed += image.bytes
                } else {
                    failures.append(.init(id: image.id, message: Self.firstMeaningfulLine(output.output)))
                }

            case let .trashDirectory(url):
                let size = image.bytes > 0 ? image.bytes : measure(url)
                do {
                    try trashItem(url)
                    removedIDs.append(image.id)
                    reclaimed += size
                } catch {
                    failures.append(.init(id: image.id, message: error.localizedDescription))
                }
            }
        }

        return EmulatorCleanupResult(
            removedIDs: removedIDs,
            totalBytesReclaimed: reclaimed,
            failures: failures
        )
    }
}

// MARK: - JSON + parsing helpers

extension EmulatorManagementService {
    /// Maps an Apple platform identifier (or runtime identifier) to a friendly OS name.
    static func applePlatformName(platformIdentifier: String?, runtimeIdentifier: String?) -> String {
        switch platformIdentifier {
        case "com.apple.platform.iphonesimulator": return "iOS"
        case "com.apple.platform.appletvsimulator": return "tvOS"
        case "com.apple.platform.watchsimulator": return "watchOS"
        case "com.apple.platform.xrsimulator": return "visionOS"
        default: break
        }
        // Fallback: com.apple.CoreSimulator.SimRuntime.iOS-26-5 → "iOS"
        if let runtimeIdentifier, let suffix = runtimeIdentifier.split(separator: ".").last {
            return String(suffix.prefix { $0.isLetter })
        }
        return "Simulator"
    }

    /// "android-36" → "API 36"; non-numeric previews keep their name ("API TiramisuPrivacySandbox").
    static func androidAPILabel(from directoryName: String) -> String {
        let level = directoryName.hasPrefix("android-")
            ? String(directoryName.dropFirst("android-".count))
            : directoryName
        return "API \(level)"
    }

    /// Immediate real subdirectories, skipping hidden entries and symlinks.
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
            return (values?.isDirectory ?? url.hasDirectoryPath) && (values?.isSymbolicLink != true)
        }
    }

    private static func firstMeaningfulLine(_ output: String) -> String {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "The simulator tool reported an error."
    }
}

// MARK: - Live implementation

extension EmulatorManagementService {
    static let live = EmulatorManagementService(
        runCommand: { tool, arguments in
            await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = tool
                process.arguments = arguments

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
        locateXcrun: {
            let url = URL(fileURLWithPath: "/usr/bin/xcrun")
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        },
        androidSystemImagesRoot: {
            let fileManager = FileManager.default
            let environment = ProcessInfo.processInfo.environment
            var roots: [URL] = []
            for key in ["ANDROID_SDK_ROOT", "ANDROID_HOME"] where environment[key] != nil {
                if let path = environment[key] { roots.append(URL(fileURLWithPath: path)) }
            }
            roots.append(fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Android/sdk"))
            for root in roots {
                let images = root.appendingPathComponent("system-images")
                if fileManager.fileExists(atPath: images.path) { return images }
            }
            return nil
        },
        measure: { StorageFormatting.itemSize(at: $0) },
        trashItem: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    )
}

// MARK: - simctl JSON

/// One entry from `xcrun simctl runtime list -j` (keyed by UUID at the top level). All fields except
/// `identifier` are optional in the output; `deletable` defaults to `false` so a missing flag never
/// makes a bundled runtime appear removable.
private struct RuntimeJSON: Decodable {
    let identifier: String
    let version: String?
    let build: String?
    let deletable: Bool
    let sizeBytes: Int64?
    let platformIdentifier: String?
    let runtimeIdentifier: String?
    let lastUsedAt: String?

    private enum CodingKeys: String, CodingKey {
        case identifier, version, build, deletable, sizeBytes
        case platformIdentifier, runtimeIdentifier, lastUsedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        build = try container.decodeIfPresent(String.self, forKey: .build)
        deletable = try container.decodeIfPresent(Bool.self, forKey: .deletable) ?? false
        sizeBytes = try container.decodeIfPresent(Int64.self, forKey: .sizeBytes)
        platformIdentifier = try container.decodeIfPresent(String.self, forKey: .platformIdentifier)
        runtimeIdentifier = try container.decodeIfPresent(String.self, forKey: .runtimeIdentifier)
        lastUsedAt = try container.decodeIfPresent(String.self, forKey: .lastUsedAt)
    }
}
