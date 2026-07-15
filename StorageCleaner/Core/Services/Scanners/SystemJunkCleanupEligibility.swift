import Foundation

/// Keeps System Junk scan results aligned with what the cleanup service can actually move to
/// Trash. Reading an item is not enough: macOS can allow enumeration while denying removal from
/// protected locations such as `~/Library/Containers`.
struct SystemJunkCleanupEligibility: Sendable {
    private let canDelete: @Sendable (URL) -> Bool

    init(
        canDelete: @escaping @Sendable (URL) -> Bool = { url in
            FileManager.default.isDeletableFile(atPath: url.path)
        }
    ) {
        self.canDelete = canDelete
    }

    func contains(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL
        guard !SystemJunkProtectionPolicy.protects(standardizedURL) else { return false }
        return canDelete(standardizedURL)
    }
}
