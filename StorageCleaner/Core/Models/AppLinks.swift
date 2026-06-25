import Foundation

/// Centralized outbound URLs the app can open (terms, privacy, support,
/// marketing). Keeping them in one place means a marketing/website
/// change is a one-line edit instead of a hunt through the codebase.
///
/// Update `terms` and `privacy` to the URLs you publish in App Store
/// Connect before the first paid release — App Review requires a
/// working EULA link on every auto-renewable subscription.
enum AppLinks {
    /// End User License Agreement. Required by App Review guideline
    /// 3.1.2 for any auto-renewable subscription.
    static let terms = URL(string: "https://storagecleaner.app/terms")!
    /// Privacy Policy. Required by App Review for any app that
    /// collects data — and shown in the paywall so subscribers know
    /// what they're agreeing to.
    static let privacy = URL(string: "https://storagecleaner.app/privacy")!
}
