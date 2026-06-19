import Foundation

struct CandidateFindingBuilder: Sendable {
    func makeFinding(
        kind: StorageFindingKind,
        domain: StorageDomain,
        candidates: [FileCandidate],
        safety: CleanupSafety
    ) -> StorageFinding? {
        let bytes = candidates.reduce(Int64(0)) { $0 + $1.bytes }
        guard bytes > 0 else { return nil }

        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: candidates.count,
            safety: safety,
            examples: Array(candidates.prefix(3).map(\.displayName)),
            filePaths: candidates.map(\.url)
        )
    }

    /// Builds a duplicate finding whose `bytes`/`itemCount`/`filePaths` describe the *removable*
    /// copies (so dashboard reclaim math stays correct), while `duplicateGroups` carries the full
    /// grouping (including the kept copy) for the grouped Duplicates UI.
    func makeDuplicateFinding(
        kind: StorageFindingKind,
        domain: StorageDomain,
        groups: [DuplicateGroup],
        safety: CleanupSafety
    ) -> StorageFinding? {
        guard !groups.isEmpty else { return nil }

        let removableURLs = groups.flatMap(\.removableURLs)
        let bytes = groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        guard bytes > 0, !removableURLs.isEmpty else { return nil }

        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: removableURLs.count,
            safety: safety,
            examples: Array(removableURLs.prefix(3).map(\.lastPathComponent)),
            filePaths: removableURLs,
            duplicateGroups: groups
        )
    }
}
