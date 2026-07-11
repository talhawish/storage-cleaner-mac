import Foundation

// MARK: - JSON + parsing helpers

/// Pure parsing / naming helpers for ``EmulatorManagementService``. Split out
/// so the service file stays under the 620-line SwiftLint limit; everything
/// here is side-effect free and directly unit-tested.
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
    static func parseSimulatorDeviceName(_ folderName: String) -> SimulatorDeviceMetadata {
        SimulatorDeviceMetadata(
            title: String(folderName.prefix(8)),
            versionLabel: "0",
            detail: "Orphaned simulator device"
        )
    }

    static func simulatorDeviceDirectory(for device: SimulatorDeviceJSON, root: URL?) -> URL? {
        if let dataPath = device.dataPath {
            let dataURL = URL(fileURLWithPath: dataPath)
            return dataURL.lastPathComponent == "data" ? dataURL.deletingLastPathComponent() : dataURL
        }
        return root?.appendingPathComponent(device.udid, isDirectory: true)
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

    static func firstMeaningfulLine(_ output: String) -> String {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "The simulator tool reported an error."
    }
}
