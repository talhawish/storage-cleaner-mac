import Foundation

/// Discovers and removes simulator/emulator **OS images** — the biggest space hogs in a developer's
/// toolchain (an Apple runtime is often 8+ GB; Android system images run several GB per API level).
///
/// The Emulators view also surfaces two adjacent categories developers ask about but which are not
/// OS images per se:
/// * iOS / tvOS / watchOS / visionOS **Device Support** — DWARF debug-symbol packs Xcode downloads
///   when you connect a real device. Each pack is 4–6 GB and they are re-downloaded on demand.
/// * **Simulator device instances** — individual iPhone / iPad / Apple Watch devices CoreSimulator
///   creates on top of a runtime. Orphaned instances (whose runtime is gone) are pure waste and
///   can be several GB each.
///
/// Removal is the safest mechanism per platform:
/// * Apple simulator runtimes live under SIP-protected `/System/Library/AssetsV2`, so they are removed
///   with `xcrun simctl runtime delete` (permanent, but re-downloadable from Apple).
/// * Simulator device instances use `xcrun simctl delete <udid>` (re-creatable from Xcode).
/// * Android system images and Device Support packs are user-owned folders, so they are moved to the
///   Trash (restorable).
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
    /// Apple Device Support roots (iOS, tvOS, watchOS, visionOS). Empty array when no Xcode developer
    /// folder exists yet.
    var appleDeviceSupportRoots: @Sendable () -> [URL]
    /// Reads the `Info.plist` `Version` key from a Device Support pack. Defaults to the version
    /// embedded in the folder name when the plist is missing.
    var readDeviceSupportVersion: @Sendable (_ folder: URL) -> String?
    /// Root of the simulator device instances directory, or nil when no Xcode is installed.
    var simulatorDevicesRoot: @Sendable () -> URL?
    /// Measures an item's on-disk size.
    var measure: @Sendable (_ url: URL) -> Int64
    /// Moves an item to the Trash.
    var trashItem: @Sendable (_ url: URL) throws -> Void

    // MARK: - Discovery

    /// Every installed image the Emulators view can manage, sorted by platform then newest → oldest.
    /// Apple runtime sizes come from simctl (instant); everything else is returned with
    /// `bytes == 0` and sized separately via ``measuringRemainingSizes(in:)`` so the list can appear
    /// immediately.
    func discover() async -> [EmulatorImage] {
        // The only async work is the simctl call; the rest is filesystem walking, which is fast
        // enough to do sequentially without blocking the main thread.
        let runtimes = await discoverAppleRuntimes()
        let deviceSupport = discoverAppleDeviceSupport()
        let simulatorDevices = discoverSimulatorDevices()
        let android = discoverAndroidImages()
        return (runtimes + deviceSupport + simulatorDevices + android).sorted { lhs, rhs in
            if lhs.platform.sortIndex != rhs.platform.sortIndex {
                return lhs.platform.sortIndex < rhs.platform.sortIndex
            }
            return lhs.key > rhs.key
        }
    }

    /// Returns `images` with the on-disk size of every trash-managed entry filled in. Apple
    /// runtimes and CoreSimulator devices are already sized at discovery time, so they pass through
    /// unchanged.
    func measuringRemainingSizes(in images: [EmulatorImage]) -> [EmulatorImage] {
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

    private func discoverAppleDeviceSupport() -> [EmulatorImage] {
        appleDeviceSupportRoots().flatMap { root -> [EmulatorImage] in
            let platformName = Self.appleDeviceSupportPlatformName(forRoot: root)
            return Self.subdirectories(of: root).compactMap { folder in
                Self.deviceSupportImage(
                    folder: folder,
                    platformName: platformName
                ) { [readDeviceSupportVersion] url in readDeviceSupportVersion(url) }
            }
        }
    }

    private func discoverSimulatorDevices() -> [EmulatorImage] {
        guard let root = simulatorDevicesRoot() else { return [] }
        return Self.subdirectories(of: root).compactMap { deviceDir -> EmulatorImage? in
            // The data path may live inside the device directory; simctl's dataPathSize is the
            // canonical size. We measure directly so orphaned devices (no simctl entry) still
            // surface with an accurate byte count.
            let folderName = deviceDir.lastPathComponent
            let metadata = Self.simulatorDeviceMetadata(at: deviceDir) ?? Self.parseSimulatorDeviceName(folderName)
            return EmulatorImage(
                id: deviceDir.path,
                platform: .simulatorDevices,
                title: metadata.title,
                versionLabel: metadata.versionLabel,
                key: VersionKey.parse(metadata.versionLabel),
                bytes: 0,
                detail: metadata.detail,
                removal: .trashDirectory(deviceDir),
                isRemovable: true,
                lastUsed: nil
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

            case let .simctlDevice(udid):
                guard let xcrun else {
                    failures.append(.init(id: image.id, message: "Xcode command-line tools not found."))
                    continue
                }
                let output = await runCommand(xcrun, ["simctl", "delete", udid])
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

    /// Maps a Device Support root directory to its friendly OS name. The trailing folder name
    /// encodes the OS (`iOS`, `tvOS`, `watchOS`, `visionOS`).
    static func appleDeviceSupportPlatformName(forRoot root: URL) -> String {
        switch root.lastPathComponent {
        case "iOS DeviceSupport": return "iOS"
        case "tvOS DeviceSupport": return "tvOS"
        case "watchOS DeviceSupport": return "watchOS"
        case "visionOS DeviceSupport": return "visionOS"
        default: return "Apple"
        }
    }

    /// Builds a Device Support image from a folder like `iPhone15,3 26.5 (23F77)`. The version is
    /// read from the on-disk `Info.plist` when present (so pre-release / older versions surface
    /// correctly); otherwise the version is extracted from the folder name. The build identifier
    /// in parentheses is preserved in the detail line.
    static func deviceSupportImage(
        folder: URL,
        platformName: String,
        versionReader: (URL) -> String?
    ) -> EmulatorImage? {
        let folderName = folder.lastPathComponent
        let plistVersion = versionReader(folder)
        let parsed = parseDeviceSupportName(folderName)
        let version = plistVersion ?? parsed.version ?? folderName
        let detail = "Build \(parsed.build ?? "—")"
        return EmulatorImage(
            id: folder.path,
            platform: .iosDeviceSupport,
            title: "\(platformName) \(version)\(parsed.deviceSuffix.map { " · \($0)" } ?? "")",
            versionLabel: version,
            key: VersionKey.parse(version),
            bytes: 0,
            detail: detail,
            removal: .trashDirectory(folder),
            isRemovable: true,
            lastUsed: nil
        )
    }

    /// Parses a folder name like `iPhone15,3 26.5 (23F77)` into its `(device, version, build)`
    /// components. Returns `nil` parts when a component is missing.
    static func parseDeviceSupportName(_ name: String) -> DeviceSupportNameComponents {
        // Strip the build suffix `(...)` if present.
        var working = name
        var build: String?
        if let openParen = working.lastIndex(of: "("), working.hasSuffix(")") {
            let inner = String(working[working.index(after: openParen)..<working.index(before: working.endIndex)])
            build = inner
            working = String(working[..<openParen]).trimmingCharacters(in: .whitespaces)
        }

        // Split remaining `device version` on the last whitespace so multi-segment versions like
        // `26.4.1` stay intact.
        guard let lastSpace = working.lastIndex(of: " ") else {
            return DeviceSupportNameComponents(deviceSuffix: working, version: nil, build: build)
        }
        let device = String(working[..<lastSpace]).trimmingCharacters(in: .whitespaces)
        let version = String(working[working.index(after: lastSpace)...]).trimmingCharacters(in: .whitespaces)
        return DeviceSupportNameComponents(
            deviceSuffix: device.isEmpty ? nil : device,
            version: version.isEmpty ? nil : version,
            build: build
        )
    }

    /// "android-36" → "API 36"; non-numeric previews keep their name ("API TiramisuPrivacySandbox").
    static func androidAPILabel(from directoryName: String) -> String {
        let level = directoryName.hasPrefix("android-")
            ? String(directoryName.dropFirst("android-".count))
            : directoryName
        return "API \(level)"
    }

    /// Best-effort metadata for a simulator device instance folder. The folder name is a UUID
    /// (e.g. `A01F28DA-DDAC-446E-B66B-8F7D47A7FDF0`), so the human-readable name comes from
    /// `device.plist` when present.
    static func simulatorDeviceMetadata(at directory: URL) -> SimulatorDeviceMetadata? {
        let plist = directory.appendingPathComponent("device.plist")
        guard let data = try? Data(contentsOf: plist),
              let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return nil
        }
        let dict = raw as? [String: Any] ?? [:]
        let name = (dict["name"] as? String) ?? (dict["deviceName"] as? String) ?? directory.lastPathComponent
        let runtime = (dict["runtime"] as? String) ?? ""
        let version = Self.runtimeVersionLabel(from: runtime)
        let detail = runtime.isEmpty ? "Orphaned simulator device" : "Runtime: \(runtime)"
        return SimulatorDeviceMetadata(title: name, versionLabel: version, detail: detail)
    }

    /// Falls back to deriving a title from the folder contents (e.g. `device.plist` not present).
    private static func parseSimulatorDeviceName(_ folderName: String) -> SimulatorDeviceMetadata {
        SimulatorDeviceMetadata(
            title: String(folderName.prefix(8)),
            versionLabel: "0",
            detail: "Orphaned simulator device"
        )
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-26-4" → "iOS 26.4"
    static func runtimeVersionLabel(from runtimeIdentifier: String) -> String {
        let lastSegment = runtimeIdentifier.split(separator: ".").last.map(String.init) ?? runtimeIdentifier
        // "iOS-26-4" → "iOS 26.4"
        let pieces = lastSegment.split(separator: "-").map(String.init)
        guard let head = pieces.first else { return lastSegment }
        let tail = pieces.dropFirst().joined(separator: ".")
        return tail.isEmpty ? head : "\(head) \(tail)"
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
            roots.append(UserHomeDirectory.url.appendingPathComponent("Library/Android/sdk"))
            for root in roots {
                let images = root.appendingPathComponent("system-images")
                if fileManager.fileExists(atPath: images.path) { return images }
            }
            return nil
        },
        appleDeviceSupportRoots: {
            DependencyPaths.Apple.deviceSupportRoots.filter { url in
                FileManager.default.fileExists(atPath: url.path)
            }
        },
        readDeviceSupportVersion: { folder in
            let plistURL = folder.appendingPathComponent("Info.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dict = raw as? [String: Any],
                  let version = dict["Version"] as? String else {
                return nil
            }
            return version
        },
        simulatorDevicesRoot: {
            let url = DependencyPaths.Apple.coreSimulator.appendingPathComponent("Devices")
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
