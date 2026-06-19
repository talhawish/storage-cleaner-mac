import Foundation

/// The minimum size a file must reach to surface in the Large Files screen.
/// User-configurable in Settings and on the Large Files screen; the raw value is the
/// threshold in megabytes so it stores cleanly in `@AppStorage`.
///
/// This is the single source of truth for the threshold option list, its byte conversion,
/// and its display label — every picker and the scan collection floor derive from it.
enum LargeFileThreshold: Int, CaseIterable, Identifiable, Codable, Sendable {
    case tenMB = 10
    case fiftyMB = 50
    case hundredMB = 100
    case fiveHundredMB = 500
    case oneGB = 1000
    case fiveGB = 5000

    var id: Int { rawValue }

    /// The threshold in megabytes (matches the value persisted in `@AppStorage`).
    var megabytes: Int { rawValue }

    /// The threshold in bytes, used by the scanner and display filter.
    var bytes: Int64 { Int64(rawValue) * 1_000_000 }

    /// Localized-friendly label for pickers (e.g. "100 MB", "1 GB").
    var label: String { StorageFormatting.bytes(bytes) }

    /// The `@AppStorage` key shared by every threshold control.
    static let storageKey = "largeFileThresholdMB"

    /// The default threshold applied before the user changes it.
    static let defaultMegabytes = LargeFileThreshold.hundredMB.megabytes

    /// The smallest selectable threshold. The scanner collects from this floor so the
    /// display filter can range across every option without rescanning.
    static var collectionFloor: LargeFileThreshold {
        allCases.min(by: { $0.rawValue < $1.rawValue }) ?? .tenMB
    }
}
