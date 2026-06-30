import Foundation
import Observation

/// One row in the Cleanup History breakdown — the storage category that was cleaned, with the
/// aggregated item count, bytes reclaimed, and a handful of representative paths. Computed from
/// `StoredCleanupAction` so the list is the single source of truth for what was removed.
struct CleanupCategorySummary: Identifiable, Equatable, Sendable {
    let kind: StorageFindingKind
    let bytesReclaimed: Int64
    let itemCount: Int
    let samplePaths: [URL]

    var id: StorageFindingKind { kind }

    var domain: StorageDomain { kind.defaultDomain }
}

/// Everything the Cleanup History detail sheet needs to render — derived from a single
/// `StoredScan` and its `cleanupActions`. Decoupled from SwiftData so it can be constructed
/// synchronously inside the view's body without re-issuing fetches.
struct CleanupScanSummary: Identifiable, Equatable, Sendable {
    let scanID: Int
    let date: Date
    let durationSeconds: Double
    let scannedItemCount: Int
    let categoriesFound: Int
    let reclaimableBytes: Int64
    let categories: [CleanupCategorySummary]
    let totalItemsCleaned: Int
    let totalBytesCleaned: Int64
    /// Free bytes on the volume when the scan started. `0` for legacy scans
    /// that pre-date the disk-tracking field.
    let freeBytesBefore: Int64
    /// Free bytes on the volume after every cleanup action for this scan ran.
    /// `0` when no cleanup ran (a scan-only event) or the volume attributes
    /// couldn't be re-read after the cleanup.
    let freeBytesAfter: Int64
    /// Total capacity of the volume the scan was run against. Used to render
    /// the usage fraction and to gate the "free before / after" pill behind
    /// `hasDiskSnapshot`.
    let volumeTotalBytes: Int64

    var id: Int { scanID }
    var hasCleanup: Bool { !categories.isEmpty }
    /// `true` when the persisted scan captured enough disk information to
    /// render the "free before / after" pill. Older scans (and scans run
    /// without FDA) leave this `false` so the UI gracefully omits the pill.
    var hasDiskSnapshot: Bool { volumeTotalBytes > 0 }
    /// Bytes the cleanup made available on the volume. `nil` until a cleanup
    /// has actually run *and* the post-cleanup free bytes were captured.
    var freedBytesByCleanup: Int64? {
        guard hasCleanup, hasDiskSnapshot, freeBytesAfter > 0, freeBytesBefore > 0 else { return nil }
        return max(0, freeBytesAfter - freeBytesBefore)
    }
}

/// One row in the lifetime "Top Cleaned Categories" roll-up. Aggregates bytes and item counts for a
/// single `StorageFindingKind` across every persisted `StoredCleanupAction`, so the hero card can
/// show what's been removed most across the app's lifetime.
struct TopCleanedCategory: Identifiable, Equatable, Sendable {
    let kind: StorageFindingKind
    let bytesReclaimed: Int64
    let itemCount: Int
    let scanCount: Int
    /// Fraction (0–1) of the lifetime cleaned bytes represented by this category.
    let share: Double

    var id: StorageFindingKind { kind }
    var domain: StorageDomain { kind.defaultDomain }
}

/// Cleanup History's derived state: lifetime totals for the summary header, plus a
/// per-scan mapping the rows and detail sheet read from. Lives in the view model so the
/// layout only deals with `Identifiable` value types and tests can drive it directly.
@MainActor
@Observable
final class CleanupHistoryViewModel {
    private(set) var summaries: [CleanupScanSummary] = []
    private(set) var totalScans: Int = 0
    private(set) var totalScansWithCleanup: Int = 0
    private(set) var totalBytesReclaimed: Int64 = 0
    private(set) var totalItemsReclaimed: Int = 0
    private(set) var lastCleanupDate: Date?
    private(set) var firstCleanupDate: Date?
    private(set) var largestCleanup: LargestCleanup?
    private(set) var bytesReclaimedThisMonth: Int64 = 0
    private(set) var itemsReclaimedThisMonth: Int = 0
    private(set) var topCategories: [TopCleanedCategory] = []

    /// The single most-reclaimed scan in the persisted history, if any. Drives the "Biggest
    /// Cleanup" stat tile — `nil` until the user has actually cleaned something.
    struct LargestCleanup: Equatable, Sendable {
        let date: Date
        let bytes: Int64
        let items: Int
    }

    func update(with scans: [StoredScan]) {
        let mapped = scans.map(Self.summary(from:))
        summaries = mapped
        totalScans = scans.count
        totalScansWithCleanup = mapped.filter(\.hasCleanup).count
        totalBytesReclaimed = mapped.reduce(Int64(0)) { $0 + $1.totalBytesCleaned }
        totalItemsReclaimed = mapped.reduce(0) { $0 + $1.totalItemsCleaned }
        let cleanupDates = mapped.filter(\.hasCleanup).map(\.date)
        lastCleanupDate = cleanupDates.max()
        firstCleanupDate = cleanupDates.min()
        largestCleanup = mapped
            .filter(\.hasCleanup)
            .max(by: { $0.totalBytesCleaned < $1.totalBytesCleaned })
            .map {
                LargestCleanup(
                    date: $0.date,
                    bytes: $0.totalBytesCleaned,
                    items: $0.totalItemsCleaned
                )
            }

        let (monthBytes, monthItems) = Self.currentMonthTotals(in: mapped)
        bytesReclaimedThisMonth = monthBytes
        itemsReclaimedThisMonth = monthItems

        topCategories = Self.topCategories(from: mapped, limit: 6)
    }

    /// Aggregates lifetime category totals across every scan, sorted by bytes reclaimed, and
    /// returns up to `limit` entries with their share of the lifetime total.
    static func topCategories(from summaries: [CleanupScanSummary], limit: Int) -> [TopCleanedCategory] {
        guard limit > 0 else { return [] }
        var bytesByKind: [StorageFindingKind: Int64] = [:]
        var itemsByKind: [StorageFindingKind: Int] = [:]
        var scanCountByKind: [StorageFindingKind: Int] = [:]
        for summary in summaries where summary.hasCleanup {
            for category in summary.categories {
                bytesByKind[category.kind, default: 0] += category.bytesReclaimed
                itemsByKind[category.kind, default: 0] += category.itemCount
                scanCountByKind[category.kind, default: 0] += 1
            }
        }
        let totalBytes = bytesByKind.values.reduce(Int64(0), +)
        guard totalBytes > 0 else { return [] }
        let sorted = bytesByKind
            .map { kind, bytes in
                TopCleanedCategory(
                    kind: kind,
                    bytesReclaimed: bytes,
                    itemCount: itemsByKind[kind, default: 0],
                    scanCount: scanCountByKind[kind, default: 0],
                    share: Double(bytes) / Double(totalBytes)
                )
            }
            .sorted { $0.bytesReclaimed > $1.bytesReclaimed }
        return Array(sorted.prefix(limit))
    }

    /// Sums bytes and items cleaned in the current calendar month — drives the "This Month" stat
    /// tile on the hero.
    static func currentMonthTotals(in summaries: [CleanupScanSummary]) -> (bytes: Int64, items: Int) {
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        guard let monthInterval else { return (0, 0) }
        let inMonth = summaries.filter { summary in
            guard summary.hasCleanup else { return false }
            return monthInterval.contains(summary.date)
        }
        let bytes = inMonth.reduce(Int64(0)) { $0 + $1.totalBytesCleaned }
        let items = inMonth.reduce(0) { $0 + $1.totalItemsCleaned }
        return (bytes, items)
    }

    /// Reduces a `StoredScan` and its actions into the sheet-ready summary. Pure: the caller
    /// passes the scan and we re-derive everything from its relationships, so the sheet always
    /// reflects the current persisted state.
    static func summary(from scan: StoredScan) -> CleanupScanSummary {
        let categories = scan.cleanupActions
            .compactMap { action -> CleanupCategorySummary? in
                guard let kind = StorageFindingKind(rawValue: action.kindRaw) else { return nil }
                guard action.itemCount > 0, action.bytesReclaimed >= 0 else { return nil }
                return CleanupCategorySummary(
                    kind: kind,
                    bytesReclaimed: action.bytesReclaimed,
                    itemCount: action.itemCount,
                    samplePaths: action.samplePaths ?? []
                )
            }
            .sorted { $0.bytesReclaimed > $1.bytesReclaimed }

        let totalBytes = categories.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        let totalItems = categories.reduce(0) { $0 + $1.itemCount }

        return CleanupScanSummary(
            scanID: scan.persistentModelID.hashValue,
            date: scan.date,
            durationSeconds: scan.durationSeconds,
            scannedItemCount: scan.scannedItemCount,
            categoriesFound: scan.findings.count,
            reclaimableBytes: scan.reclaimableBytes,
            categories: categories,
            totalItemsCleaned: totalItems,
            totalBytesCleaned: totalBytes,
            freeBytesBefore: scan.freeBytesBefore,
            freeBytesAfter: scan.freeBytesAfter,
            volumeTotalBytes: scan.volumeTotalBytes
        )
    }
}

private extension StorageFindingKind {
    /// Convenience mapping from a persisted cleanup kind to its UI `StorageDomain`. Mirrors the
    /// scan pipeline's mapping; if a kind has no canonical domain, fall back to `.otherCaches`.
    var defaultDomain: StorageDomain {
        switch self {
        case .xcodeArtifacts, .iosDeviceSupport: .appleDevelopment
        case .nodeDependencies: .webDevelopment
        case .browserCaches: .browserData
        case .dockerArtifacts: .containers
        case .flutterArtifacts, .reactNativeArtifacts, .androidStudioArtifacts, .androidPackages: .mobileDevelopment
        case .aiModelCaches: .artificialIntelligence
        case .largeFiles, .largeVideos, .screenRecordings: .media
        case .largePhotos, .duplicatePhotos: .photos
        case .duplicateDocuments, .junkFiles: .documents
        case .duplicateVideos: .media
        case .screenshots: .screenshots
        case .pythonDependencies, .rubyDependencies, .phpDependencies, .goDependencies,
             .rustDependencies, .dotnetDependencies, .gradleDependencies: .webDevelopment
        case .cliApps: .cliTooling
        case .runtimeVersions: .otherCaches
        case .installerLeftovers: .leftovers
        case .orphanedAppSupport, .orphanedAppCaches, .orphanedAppContainers,
             .orphanedAppPreferences, .oldCrashReports: .systemJunk
        case .trash: .trash
        }
    }
}
