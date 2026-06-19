import Foundation

/// Pure, snapshot-derived aggregations for the Overview screen: how reclaimable storage rolls up by
/// `StorageDomain` and how it splits across `CleanupSafety`. Mirrors the `DeveloperDomains` pattern —
/// a single, testable source of truth so `DashboardViewModel` and the views stay logic-free.
enum StorageOverview {
    /// One domain's rolled-up usage across the findings in that domain.
    struct DomainUsage: Identifiable, Equatable {
        let domain: StorageDomain
        let bytes: Int64
        let itemCount: Int
        /// Fraction (0–1) of the snapshot's total reclaimable bytes.
        let share: Double
        let safeBytes: Int64
        let reviewBytes: Int64
        /// Findings backing this group, sorted by bytes descending.
        let findings: [StorageFinding]
        /// `true` for the synthetic tile that folds together domains beyond the tile cap.
        let isOther: Bool

        /// Distinct even when `isOther` reuses `.otherCaches`, so a real Other Caches group and the
        /// synthetic roll-up never collide in a `ForEach`.
        var id: String { isOther ? "overview-other-rollup" : domain.rawValue }

        var displayTitle: String { isOther ? "Other" : domain.title }

        var shareLabel: String { "\(Int((share * 100).rounded()))%" }
    }

    /// Every domain present in the findings, rolled up and sorted by bytes descending. Zero-byte
    /// findings are dropped so empty domains never appear.
    static func domainUsages(in findings: [StorageFinding]) -> [DomainUsage] {
        let relevant = findings.filter { $0.bytes > 0 }
        let total = relevant.reduce(Int64(0)) { $0 + $1.bytes }
        guard total > 0 else { return [] }

        return Dictionary(grouping: relevant, by: \.domain)
            .map { usage(domain: $0.key, findings: $0.value, total: total, isOther: false) }
            .sorted(by: sortUsages)
    }

    /// The top `maxTiles` domains for the breakdown grid. When more domains exist, the remainder are
    /// folded into a single synthetic "Other" tile (using `.otherCaches` metadata) so the grid stays
    /// scannable.
    static func tiles(in findings: [StorageFinding], maxTiles: Int) -> [DomainUsage] {
        let usages = domainUsages(in: findings)
        guard maxTiles > 0, usages.count > maxTiles else { return usages }

        let total = usages.reduce(Int64(0)) { $0 + $1.bytes }
        let top = Array(usages.prefix(maxTiles - 1))
        let restFindings = usages.dropFirst(maxTiles - 1).flatMap(\.findings)
        let other = usage(domain: .otherCaches, findings: restFindings, total: total, isOther: true)
        return top + [other]
    }

    /// Total bytes for findings marked safe to clean.
    static func safeBytes(in findings: [StorageFinding]) -> Int64 {
        bytes(in: findings, safety: .safe)
    }

    /// Total bytes for findings that need review before cleaning.
    static func reviewBytes(in findings: [StorageFinding]) -> Int64 {
        bytes(in: findings, safety: .review)
    }

    private static func bytes(in findings: [StorageFinding], safety: CleanupSafety) -> Int64 {
        findings.filter { $0.safety == safety }.reduce(Int64(0)) { $0 + $1.bytes }
    }

    private static func sortUsages(_ lhs: DomainUsage, _ rhs: DomainUsage) -> Bool {
        if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
        return lhs.domain.title < rhs.domain.title
    }

    private static func usage(
        domain: StorageDomain,
        findings: [StorageFinding],
        total: Int64,
        isOther: Bool
    ) -> DomainUsage {
        let bytes = findings.reduce(Int64(0)) { $0 + $1.bytes }
        let items = findings.reduce(0) { $0 + $1.itemCount }
        return DomainUsage(
            domain: domain,
            bytes: bytes,
            itemCount: items,
            share: total > 0 ? Double(bytes) / Double(total) : 0,
            safeBytes: safeBytes(in: findings),
            reviewBytes: reviewBytes(in: findings),
            findings: findings.sorted { $0.bytes > $1.bytes },
            isOther: isOther
        )
    }
}
