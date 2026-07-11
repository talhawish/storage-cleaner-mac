import Foundation

/// Result of an emulator inventory pass. `failureMessage` is set when a probe
/// failed outright (e.g. `simctl` errored even though the Xcode tooling is
/// installed) so the UI can distinguish "nothing installed" from "the
/// inventory is unreliable" instead of showing a misleading empty state.
struct EmulatorDiscovery: Sendable {
    let images: [EmulatorImage]
    let failureMessage: String?
}

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
        await discoverWithDiagnostics().images
    }

    /// Like ``discover()``, but also reports when a probe failed outright — e.g. `simctl`
    /// returned a non-zero exit even though the Xcode tooling is installed. Lets the
    /// Emulators view distinguish "nothing installed" from "the inventory is unreliable".
    func discoverWithDiagnostics() async -> EmulatorDiscovery {
        // The only async work is the simctl call; the rest is filesystem walking, which is fast
        // enough to do sequentially without blocking the main thread.
        let runtimes = await discoverAppleRuntimes()
        let deviceSupport = discoverAppleDeviceSupport()
        let simulatorDevices = await discoverSimulatorDevices()
        let android = discoverAndroidImages()
        let images = (runtimes.images + deviceSupport + simulatorDevices.images + android)
            .sorted { lhs, rhs in
                if lhs.platform.sortIndex != rhs.platform.sortIndex {
                    return lhs.platform.sortIndex < rhs.platform.sortIndex
                }
                return lhs.key > rhs.key
            }
        return EmulatorDiscovery(
            images: images,
            failureMessage: runtimes.failureMessage ?? simulatorDevices.failureMessage
        )
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

    private func discoverAppleRuntimes() async -> (images: [EmulatorImage], failureMessage: String?) {
        // No xcrun means no Xcode tooling: an empty result is a true empty, not a failure.
        guard let xcrun = locateXcrun() else { return ([], nil) }
        let output = await runCommand(xcrun, ["simctl", "runtime", "list", "-j"])
        guard output.succeeded, let data = output.output.data(using: .utf8) else {
            return ([], Self.simctlFailureMessage(listing: "simulator runtimes", output: output))
        }
        guard let decoded = try? JSONDecoder().decode([String: RuntimeJSON].self, from: data) else {
            return ([], "simctl returned an unreadable simulator runtime list.")
        }

        let isoFormatter = ISO8601DateFormatter()
        let relativeFormatter = RelativeDateTimeFormatter()
        let referenceDate = Date()

        let images = decoded.values.map { runtime -> EmulatorImage in
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
        return (images, nil)
    }

    /// One-line, user-presentable description of a failed `simctl` invocation.
    private static func simctlFailureMessage(
        listing subject: String,
        output: CommandOutput
    ) -> String {
        "simctl couldn't list \(subject): \(firstMeaningfulLine(output.output))"
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

    private func discoverSimulatorDevices() async -> (images: [EmulatorImage], failureMessage: String?) {
        let simctlDevices = await discoverSimulatorDevicesFromSimctl()
        guard simctlDevices.didInspect else { return ([], simctlDevices.failureMessage) }

        let orphanedFolders = discoverOrphanedSimulatorDeviceFolders(
            excluding: simctlDevices.deviceDirectories
        )
        return (simctlDevices.images + orphanedFolders, nil)
    }

    private func discoverSimulatorDevicesFromSimctl() async -> SimulatorDeviceDiscovery {
        guard let xcrun = locateXcrun() else {
            return SimulatorDeviceDiscovery(
                images: [], deviceDirectories: [], didInspect: false, failureMessage: nil
            )
        }
        let output = await runCommand(xcrun, ["simctl", "list", "devices", "-j"])
        guard output.succeeded, let data = output.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SimulatorDevicesJSON.self, from: data) else {
            return SimulatorDeviceDiscovery(
                images: [],
                deviceDirectories: [],
                didInspect: false,
                failureMessage: Self.simctlFailureMessage(listing: "simulator devices", output: output)
            )
        }

        let isoFormatter = ISO8601DateFormatter()
        let root = simulatorDevicesRoot()
        var directories = Set<String>()
        var images: [EmulatorImage] = []

        for (runtimeIdentifier, devices) in decoded.devices {
            for device in devices {
                let directory = Self.simulatorDeviceDirectory(for: device, root: root)
                if let directory {
                    directories.insert(directory.standardizedFileURL.path)
                }
                let version = Self.runtimeVersionLabel(from: runtimeIdentifier)
                let lastUsed = device.lastBootedAt.flatMap(isoFormatter.date(from:))
                let state = device.state.map { " · \($0)" } ?? ""
                images.append(
                    EmulatorImage(
                        id: device.udid,
                        platform: .simulatorDevices,
                        title: device.name,
                        versionLabel: version,
                        key: VersionKey.parse(version),
                        bytes: device.dataPathSize ?? directory.map(measure) ?? 0,
                        detail: "Runtime: \(runtimeIdentifier)\(state)",
                        removal: .simctlDevice(udid: device.udid),
                        isRemovable: true,
                        lastUsed: lastUsed
                    )
                )
            }
        }

        return SimulatorDeviceDiscovery(
            images: images,
            deviceDirectories: directories,
            didInspect: true,
            failureMessage: nil
        )
    }

    private func discoverOrphanedSimulatorDeviceFolders(excluding knownDirectories: Set<String>) -> [EmulatorImage] {
        guard let root = simulatorDevicesRoot() else { return [] }
        return Self.subdirectories(of: root).compactMap { deviceDir -> EmulatorImage? in
            guard !knownDirectories.contains(deviceDir.standardizedFileURL.path) else {
                return nil
            }
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

private struct SimulatorDeviceDiscovery: Sendable {
    let images: [EmulatorImage]
    let deviceDirectories: Set<String>
    let didInspect: Bool
    /// Set when simctl ran but failed; `nil` when xcrun is simply absent.
    let failureMessage: String?
}

private struct SimulatorDevicesJSON: Decodable {
    let devices: [String: [SimulatorDeviceJSON]]
}

struct SimulatorDeviceJSON: Decodable, Sendable {
    let name: String
    let udid: String
    let state: String?
    let dataPath: String?
    let dataPathSize: Int64?
    let lastBootedAt: String?

    private enum CodingKeys: String, CodingKey {
        case name, udid, state, dataPath, dataPathSize, lastBootedAt
    }
}
