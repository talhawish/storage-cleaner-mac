import Foundation

/// Platform an emulator/simulator OS image belongs to.
///
/// The Emulators view groups Apple *runtimes* (downloaded by Xcode) separately from iOS Device
/// Support debug symbols and orphaned simulator device instances — they have different origins,
/// sizes, and removal semantics, even though macOS Settings > Developer lists all of them in the
/// same Developer pane.
enum EmulatorPlatform: String, CaseIterable, Identifiable, Sendable {
    case appleSimulator
    case simulatorDevices
    case iosDeviceSupport
    case androidEmulator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSimulator: "Apple Simulators"
        case .simulatorDevices: "Simulator Devices"
        case .iosDeviceSupport: "iOS Device Support"
        case .androidEmulator: "Android System Images"
        }
    }

    var subtitle: String {
        switch self {
        case .appleSimulator: "iOS, tvOS, watchOS, and visionOS simulator runtimes"
        case .simulatorDevices: "Individual simulator device instances (iPhone, iPad, Apple Watch, …)"
        case .iosDeviceSupport: "Debug symbols for symbolication when attaching a real device"
        case .androidEmulator: "Android emulator system images by API level"
        }
    }

    var symbolName: String {
        switch self {
        case .appleSimulator: "iphone.gen3"
        case .simulatorDevices: "ipad.gen2"
        case .iosDeviceSupport: "ladybug.fill"
        case .androidEmulator: "smartphone"
        }
    }

    var accentColor: StorageAccentColor {
        switch self {
        case .appleSimulator: .blue
        case .simulatorDevices: .indigo
        case .iosDeviceSupport: .violet
        case .androidEmulator: .mint
        }
    }

    /// Display order in the list. Apple runtimes first, then their device instances, then the
    /// related debug-symbol packs, then Android.
    var sortIndex: Int {
        switch self {
        case .appleSimulator: 0
        case .simulatorDevices: 1
        case .iosDeviceSupport: 2
        case .androidEmulator: 3
        }
    }
}

/// How an OS image is removed — the mechanism differs by platform, and so does reversibility.
///
/// Apple simulator runtimes live under SIP-protected `/System/Library/AssetsV2`, so the only safe
/// removal is `xcrun simctl runtime delete`: permanent, but re-downloadable from Apple. Simulator
/// device instances use `xcrun simctl delete <udid>` for the same reason — CoreSimulator owns the
/// data path. Everything else (Android system images, iOS/tvOS/watchOS/visionOS Device Support
/// debug-symbol packs) is a user-owned folder and is moved to the Trash and remains restorable.
enum EmulatorRemoval: Hashable, Sendable {
    case simctlRuntime(identifier: String)
    case simctlDevice(udid: String)
    case trashDirectory(URL)

    /// `true` when the removal can be undone (Trash). Apple runtime / device deletion is not reversible
    /// from the Trash, though the runtime can be re-downloaded and the simulator device can be
    /// re-created from Xcode.
    var isReversible: Bool {
        if case .trashDirectory = self { return true }
        return false
    }

    /// Short, honest description of what removal does — shown in the confirmation UI.
    var effectDescription: String {
        switch self {
        case .simctlRuntime: "Uninstalled · re-downloadable from Apple"
        case .simctlDevice: "Deleted · re-creatable from Xcode"
        case .trashDirectory: "Moved to Trash · restorable"
        }
    }
}

/// A single installed emulator/simulator OS image (a runtime or a system image).
struct EmulatorImage: Identifiable, Hashable, Sendable {
    /// simctl runtime identifier (UUID) for Apple, or the directory path for Android.
    let id: String
    let platform: EmulatorPlatform
    /// Headline name, e.g. "iOS 26.5" or "Android API 36 · google_apis · arm64-v8a".
    let title: String
    /// Sortable version label, e.g. "26.5" or "API 36".
    let versionLabel: String
    /// Parsed version used to sort newest → oldest within a platform.
    let key: VersionKey
    var bytes: Int64
    /// Secondary line: build / last used (Apple) or tag · ABI (Android).
    let detail: String
    let removal: EmulatorRemoval
    /// `false` when the image cannot be removed (bundled with Xcode or currently in use).
    let isRemovable: Bool
    let lastUsed: Date?
}

/// Outcome of removing a set of emulator images.
struct EmulatorCleanupResult: Sendable {
    let removedIDs: [String]
    let totalBytesReclaimed: Int64
    let failures: [Failure]

    struct Failure: Sendable {
        let id: String
        let message: String
    }

    var removedCount: Int { removedIDs.count }
}

/// Parsed components of a Device Support pack folder name (e.g. `iPhone15,3 26.5 (23F77)`).
/// Each component is `nil` when the corresponding piece is missing — the folder may not include
/// a `(build)` suffix, or the device/version pair may be combined without a separator.
struct DeviceSupportNameComponents: Equatable, Sendable {
    let deviceSuffix: String?
    let version: String?
    let build: String?
}

/// Human-readable metadata extracted from a CoreSimulator device instance folder. The folder
/// name is a UUID, so the visible title/version/detail come from `device.plist` when present.
struct SimulatorDeviceMetadata: Equatable, Sendable {
    let title: String
    let versionLabel: String
    let detail: String
}
