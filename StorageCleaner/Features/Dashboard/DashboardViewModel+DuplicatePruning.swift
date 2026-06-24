import Foundation

/// Duplicate-group delete/prune helpers for ``DashboardViewModel``. Split out
/// so the main file stays under the 620-line SwiftLint limit.
extension DashboardViewModel {
    /// Rebuilds a duplicate finding from its pruned groups. Returns `nil` when no group still has
    /// 2+ copies (nothing left to clean up).
    func prunedDuplicateFinding(
        from finding: StorageFinding,
        deletedURLs: [URL: Int64]
    ) -> StorageFinding? {
        let groups = prunedGroups(from: finding.duplicateGroups, deletedURLs: deletedURLs)
        guard !groups.isEmpty else { return nil }

        let removableURLs = groups.flatMap(\.removableURLs)
        let bytes = groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        return StorageFinding(
            kind: finding.kind,
            domain: finding.domain,
            bytes: bytes,
            itemCount: removableURLs.count,
            safety: finding.safety,
            examples: Array(removableURLs.prefix(3).map(\.lastPathComponent)),
            filePaths: removableURLs,
            duplicateGroups: groups
        )
    }

    /// Removes deleted copies from each duplicate group, drops groups that no longer have 2+ copies,
    /// and re-elects a copy to keep when the previously kept file was the one deleted.
    private func prunedGroups(
        from groups: [DuplicateGroup],
        deletedURLs: [URL: Int64]
    ) -> [DuplicateGroup] {
        groups.compactMap { group in
            let remainingFiles = group.files.filter { deletedURLs[$0.url] == nil }
            guard remainingFiles.count > 1 else { return nil }

            let keepURL = remainingFiles.contains(where: { $0.url == group.keepURL })
                ? group.keepURL
                : DuplicateKeepStrategy.bestToKeep(from: remainingFiles).url
            return DuplicateGroup(contentHash: group.contentHash, files: remainingFiles, keepURL: keepURL)
        }
    }
}
