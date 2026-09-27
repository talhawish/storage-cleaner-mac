import Foundation

/// User-facing copy for a cleanup confirmation or failure prompt. Built from a
/// `CleanupResult` so every delete path — System Junk's inline flow, the
/// app-wide failure sheet, Quick Clean — describes outcomes with the same
/// wording and recovery guidance.
struct CleanupFeedback {
    enum Operation {
        case trash
        case cliPrograms
        case runtimeVersions

        var successDescription: String {
            switch self {
            case .trash: "moved to Trash"
            case .cliPrograms, .runtimeVersions: "removed"
            }
        }

        var failureDescription: String {
            switch self {
            case .trash: "moved to Trash"
            case .cliPrograms, .runtimeVersions: "removed"
            }
        }

        var retryTitle: String {
            switch self {
            case .trash: "Retry Move"
            case .cliPrograms, .runtimeVersions: "Retry Removal"
            }
        }
    }

    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String

    static func pending(itemCount: Int, bytes: Int64) -> CleanupFeedback {
        CleanupFeedback(
            title: "Move \(itemCount) \(Self.itemLabel(itemCount)) to Trash?",
            message: "This will move \(itemCount) \(Self.itemLabel(itemCount)) to your Trash "
                + "(\(StorageFormatting.bytes(bytes))). You can recover them from Trash if needed.",
            confirmTitle: "Move to Trash",
            cancelTitle: "Cancel"
        )
    }

    static func failed(result: CleanupResult, operation: Operation = .trash) -> CleanupFeedback {
        let failedCount = result.failedCount
        let failedLabel = Self.itemLabel(failedCount)
        let recovery = Self.recoveryMessage(from: result)
        let allNeedPermission = !result.failedURLs.isEmpty
            && result.failedURLs.allSatisfy { Self.isPermissionError($0.1) }
        let failureSummary = allNeedPermission
            ? "\(failedCount) \(failedLabel) still \(Self.needsVerb(failedCount)) permission."
            : "\(failedCount) \(failedLabel) could not be \(operation.failureDescription)."

        let message: String
        if result.deletedCount > 0 {
            let movedLabel = result.deletedCount == 1 ? "item was" : "items were"
            message = "\(result.deletedCount) \(movedLabel) \(operation.successDescription). "
                + "\(failureSummary) \(recovery)"
        } else {
            message = "\(failedCount) \(failedLabel) could not be \(operation.failureDescription). \(recovery)"
        }

        return CleanupFeedback(
            title: allNeedPermission
                ? "\(failedCount) \(failedLabel) \(Self.needsVerb(failedCount)) permission"
                : "\(failedCount) \(failedLabel) could not be removed",
            message: message,
            confirmTitle: operation.retryTitle,
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
        guard let error = result.failedURLs.first?.1 else { return "Check access and retry." }
        if case CleanupError.containerAuthorizationRequired = error {
            return "Retry, then approve the macOS request to access protected app data."
        }
        let description = error.localizedDescription
        if Self.isPermissionError(error) {
            return description + " Check Storage Cleaner's access to this location, then retry."
        }
        return description
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        if case let CleanupError.deletionFailed(_, underlying) = error {
            return isPermissionError(underlying)
        }
        if case CleanupError.containerAuthorizationRequired = error { return true }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let code = CocoaError.Code(rawValue: nsError.code)
            return code == .fileWriteNoPermission || code == .fileReadNoPermission
        }
        return nsError.domain == NSPOSIXErrorDomain && (nsError.code == EACCES || nsError.code == EPERM)
    }
}
