import Foundation

/// Single source of truth for the `x-apple.systempreferences:` deep links the app opens so the
/// user can grant access. Keeping the URL strings here avoids magic strings scattered across view
/// models and tests.
enum SystemSettingsPane {
    case fullDiskAccess

    var url: URL? {
        switch self {
        case .fullDiskAccess:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        }
    }
}
