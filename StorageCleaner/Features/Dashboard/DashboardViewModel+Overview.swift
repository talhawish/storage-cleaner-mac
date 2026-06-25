import Foundation

/// Overview-derived view-model surface: the breakdown grid, the
/// per-domain tiles, the safe/review byte totals, the "ready to
/// discover" tips, the stale-project hints, and the `LastScan`
/// enum the dashboard uses to decide which sections should show
/// their pre-scan vs post-scan state.
///
/// Extracted from `DashboardViewModel.swift` to keep that file
/// under SwiftLint's 600-line warning threshold (the file is
/// already close to the limit, and the overview aggregation logic
/// stands alone).
extension DashboardViewModel {
    /// Top domains for the Overview breakdown grid, with the long tail folded into "Other".
    var domainTiles: [StorageOverview.DomainUsage] {
        StorageOverview.tiles(in: snapshot?.findings ?? [], maxTiles: 6)
    }

    /// Every present domain rolled up, backing the grouped detection rows.
    var domainGroups: [StorageOverview.DomainUsage] {
        StorageOverview.domainUsages(in: snapshot?.findings ?? [])
    }

    var safeReclaimableBytes: Int64 {
        StorageOverview.safeBytes(in: snapshot?.findings ?? [])
    }

    var reviewReclaimableBytes: Int64 {
        StorageOverview.reviewBytes(in: snapshot?.findings ?? [])
    }

    var overviewTips: [OverviewTip] {
        guard let snapshot else { return [] }
        return OverviewTipBuilder.tips(for: snapshot, stale: staleHints)
    }

    /// The current finding for a kind, used to navigate from a tip or breakdown tile.
    func finding(for kind: StorageFindingKind) -> StorageFinding? {
        snapshot?.findings.first { $0.kind == kind }
    }

    func refreshStaleHints() {
        staleTask?.cancel()
        let samples = (snapshot?.findings ?? [])
            .filter { DeveloperDomains.kinds.contains($0.kind) && $0.bytes > 0 && !$0.filePaths.isEmpty }
            .map {
                StaleSample(
                    kind: $0.kind,
                    domain: $0.domain,
                    bytes: $0.bytes,
                    paths: Array($0.filePaths.prefix(3))
                )
            }

        guard !samples.isEmpty else {
            staleHints = []
            return
        }

        staleTask = Task { [weak self] in
            let hints = await Self.computeStaleHints(from: samples)
            guard !Task.isCancelled else { return }
            self?.staleHints = hints
        }
    }

    private struct StaleSample: Sendable {
        let kind: StorageFindingKind
        let domain: StorageDomain
        let bytes: Int64
        let paths: [URL]
    }

    private static func computeStaleHints(from samples: [StaleSample]) async -> [StaleHint] {
        await Task.detached(priority: .utility) {
            let now = Date()
            return samples.compactMap { sample -> StaleHint? in
                let newest = sample.paths
                    .map { StorageFormatting.modificationDate(at: $0) }
                    .max() ?? .distantPast
                let days = Calendar.current.dateComponents([.day], from: newest, to: now).day ?? 0
                guard days >= OverviewTipBuilder.staleThresholdDays else { return nil }
                return StaleHint(
                    kind: sample.kind,
                    domain: sample.domain,
                    bytes: sample.bytes,
                    daysSinceModified: days
                )
            }
        }.value
    }
}

/// The footprint of the most recent scan, used to tell per-section views
/// whether they should show their pre-scan "ready to discover" hero or
/// their post-scan "all clean" empty state.
enum LastScan: Equatable {
    /// No scan has completed in this session.
    case never
    /// A full scan ran; every kind was covered.
    case full
    /// A targeted scan covered only the listed kinds; other kinds are
    /// still in their pre-scan state.
    case targeted(Set<StorageFindingKind>)
}
