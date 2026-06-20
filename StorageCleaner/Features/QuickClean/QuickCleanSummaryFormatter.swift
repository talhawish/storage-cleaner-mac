import Foundation

/// Renders a one-line summary of a Quick Clean cleanup result. Used by the
/// success screen and the success card on the dashboard. Kept module-internal
/// (not `private`) because both `QuickCleanView` and `QuickCleanSuccessView`
/// need it.
enum QuickCleanSummaryFormatter {
    static func summary(for result: CleanupResult) -> String {
        if result.deletedCount == 0 && result.failedCount == 0 {
            return "Nothing was removed"
        }
        var parts: [String] = []
        parts.append(
            "Reclaimed \(StorageFormatting.bytes(result.totalBytesReclaimed))"
        )
        if result.failedCount > 0 {
            let suffix = result.failedCount == 1 ? "" : "s"
            parts.append("\(result.failedCount) item\(suffix) could not be moved")
        }
        return parts.joined(separator: " · ")
    }
}
