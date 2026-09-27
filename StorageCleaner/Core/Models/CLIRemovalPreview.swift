import Foundation

/// The review copy for a CLI removal, derived from the same classification as
/// the service that performs it. No selected path is described as a full uninstall
/// unless its package manager actually handles the removal.
struct CLIRemovalPreview {
    let method: String
    let detail: String
    let canRemove: Bool

    static func forURL(_ url: URL) -> Self {
        switch CLIRemovalService.classify(url) {
        case let .homebrew(_, isCask):
            return Self(
                method: isCask ? "Uninstall Homebrew cask" : "Uninstall Homebrew formula",
                detail: "Homebrew controls which installed files are removed. "
                    + "This app does not request --zap or separately clean saved data.",
                canRemove: true
            )
        case let .nodeGlobal(plan):
            let manager = plan.toolCandidates.first?.lastPathComponent ?? "package manager"
            return Self(
                method: "Uninstall with \(manager)",
                detail: "The matching package manager must be available. "
                    + "Settings and saved data outside the package remain.",
                canRemove: true
            )
        case let .manualRemovalRequired(message):
            return Self(method: "Manual removal required", detail: message, canRemove: false)
        case .other:
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory
                ?? url.hasDirectoryPath
            return isDirectory
                ? Self(
                    method: "Move folder to Trash",
                    detail: "Everything inside this folder moves to Trash, "
                        + "including any settings or saved data stored there.",
                    canRemove: true
                )
                : Self(
                    method: "Move file to Trash",
                    detail: "Only this file moves to Trash. Settings and saved data stored elsewhere remain.",
                    canRemove: true
                )
        }
    }
}
