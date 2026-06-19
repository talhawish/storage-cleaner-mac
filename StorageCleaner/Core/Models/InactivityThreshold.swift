import Foundation

/// How long a project must sit untouched before it is offered for hibernation.
/// User-configurable in Settings; the raw value is the threshold in days so it
/// stores cleanly in `@AppStorage`.
enum InactivityThreshold: Int, CaseIterable, Identifiable, Codable, Sendable {
    case twoWeeks = 14
    case oneMonth = 30
    case threeMonths = 90
    case sixMonths = 180

    var id: Int { rawValue }

    /// The threshold in days.
    var days: Int { rawValue }

    /// Short label for pickers (e.g. the Settings segmented control).
    var title: String {
        switch self {
        case .twoWeeks: "2 weeks"
        case .oneMonth: "1 month"
        case .threeMonths: "3 months"
        case .sixMonths: "6 months"
        }
    }

    /// Phrase suitable for "untouched for over \(durationPhrase)".
    var durationPhrase: String {
        switch self {
        case .twoWeeks: "two weeks"
        case .oneMonth: "a month"
        case .threeMonths: "three months"
        case .sixMonths: "six months"
        }
    }
}
