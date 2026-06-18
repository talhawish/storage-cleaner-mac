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
}
