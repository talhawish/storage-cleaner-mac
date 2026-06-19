import Foundation

/// Platform an emulator/simulator OS image belongs to.
enum EmulatorPlatform: String, CaseIterable, Identifiable, Sendable {
    case appleSimulator
    case androidEmulator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appleSimulator: "Apple Simulators"
        case .androidEmulator: "Android System Images"
        }
    }

    var subtitle: String {
        switch self {
        case .appleSimulator: "iOS, tvOS, watchOS, and visionOS simulator runtimes"
        case .androidEmulator: "Android emulator system images by API level"
        }
    }

    var symbolName: String {
        switch self {
        case .appleSimulator: "iphone.gen3"
        case .androidEmulator: "smartphone"
        }
    }

    var accentColor: StorageAccentColor {
        switch self {
        case .appleSimulator: .blue
        case .androidEmulator: .mint
        }
    }

    /// Display order in the list.
    var sortIndex: Int {
        switch self {
        case .appleSimulator: 0
        case .androidEmulator: 1
        }
    }
}

/// How an OS image is removed — the mechanism differs by platform, and so does reversibility.
///
/// Apple simulator runtimes live under SIP-protected `/System/Library/AssetsV2`, so the only safe
/// removal is `xcrun simctl runtime delete`: permanent, but re-downloadable from Apple. Android system
/// images are user-owned folders, so they are moved to the Trash and remain restorable.
enum EmulatorRemoval: Hashable, Sendable {
    case simctlRuntime(identifier: String)
    case trashDirectory(URL)

    /// `true` when the removal can be undone (Trash). Apple runtime deletion is not reversible from
    /// the Trash, though the runtime can be re-downloaded.
    var isReversible: Bool {
        if case .trashDirectory = self { return true }
        return false
    }

    /// Short, honest description of what removal does — shown in the confirmation UI.
    var effectDescription: String {
        switch self {
        case .simctlRuntime: "Uninstalled · re-downloadable from Apple"
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
