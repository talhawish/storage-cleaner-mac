import Foundation

/// Centralized outbound URLs the app can open (terms, privacy, support,
/// marketing). Keeping them in one place means a marketing/website
/// change is a one-line edit instead of a hunt through the codebase.
///
/// Keep these values identical to the URLs supplied in App Store
/// Connect. App Review requires working EULA and privacy links for
/// every auto-renewable subscription.
enum AppLinks {
    /// Apple's Standard End User License Agreement. Required by App
    /// Review guideline 3.1.2 for any auto-renewable subscription and
    /// included verbatim in the App Store description.
    static let terms = makeURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    /// Privacy Policy. Required by App Review for any app that
    /// collects data — and shown in the paywall so subscribers know
    /// what they're agreeing to.
    static let privacy = makeURL("https://storagecleaner.horizam.com/privacy")

    private static func makeURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("Invalid app link: \(value)")
        }
        return url
    }
}
