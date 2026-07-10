import Foundation

struct SystemJunkCleanupFeedback {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String

    static func pending(itemCount: Int, bytes: Int64) -> SystemJunkCleanupFeedback {
        SystemJunkCleanupFeedback(
            title: "Move \(itemCount) \(Self.itemLabel(itemCount)) to Trash?",
            message: "This will move \(itemCount) \(Self.itemLabel(itemCount)) to your Trash "
                + "(\(StorageFormatting.bytes(bytes))). You can recover them from Trash if needed.",
            confirmTitle: "Move to Trash",
            cancelTitle: "Cancel"
        )
    }

    static func failed(result: CleanupResult) -> SystemJunkCleanupFeedback {
        let failedCount = result.failedCount
        let failedLabel = Self.itemLabel(failedCount)
        let recovery = Self.recoveryMessage(from: result)
        let message: String

        if result.deletedCount > 0 {
            let movedLabel = result.deletedCount == 1 ? "item was" : "items were"
            message = "\(result.deletedCount) \(movedLabel) moved to Trash. "
                + "\(failedCount) \(failedLabel) still \(Self.needsVerb(failedCount)) permission. \(recovery)"
        } else {
            message = "\(failedCount) \(failedLabel) could not be moved to Trash. \(recovery)"
        }

        return SystemJunkCleanupFeedback(
            title: "\(failedCount) \(failedLabel) \(Self.needsVerb(failedCount)) permission",
            message: message,
            confirmTitle: "Retry Move",
            cancelTitle: "Done"
        )
    }

    private static func itemLabel(_ count: Int) -> String {
        count == 1 ? "item" : "items"
    }

    private static func needsVerb(_ count: Int) -> String {
        count == 1 ? "needs" : "need"
    }

    private static func recoveryMessage(from result: CleanupResult) -> String {
        let fallback = "Grant Full Disk Access in System Settings, choose your Home folder again, "
            + "then retry."
        guard let error = result.failedURLs.first?.1 else { return fallback }
        let description = error.localizedDescription
        guard !description.isEmpty else { return fallback }
        return description + " " + fallback
    }
}
