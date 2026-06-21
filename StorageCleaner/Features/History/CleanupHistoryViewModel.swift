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

    var id: Int { scanID }
    var hasCleanup: Bool { !categories.isEmpty }
}

/// Cleanup History's derived state: lifetime totals for the summary header, plus a
/// per-scan mapping the rows and detail sheet read from. Lives in the view model so the
/// layout only deals with `Identifiable` value types and tests can drive it directly.
@MainActor
@Observable
final class CleanupHistoryViewModel {
    private(set) var summaries: [CleanupScanSummary] = []
    private(set) var totalScans: Int = 0
    private(set) var totalBytesReclaimed: Int64 = 0
    private(set) var totalItemsReclaimed: Int = 0
    private(set) var lastCleanupDate: Date?

    func update(with scans: [StoredScan]) {
        let mapped = scans.map(Self.summary(from:))
        summaries = mapped
        totalScans = scans.count
        totalBytesReclaimed = mapped.reduce(Int64(0)) { $0 + $1.totalBytesCleaned }
        totalItemsReclaimed = mapped.reduce(0) { $0 + $1.totalItemsCleaned }
        lastCleanupDate = mapped
            .filter(\.hasCleanup)
            .map(\.date)
            .max()
    }

    /// Reduces a `StoredScan` and its actions into the sheet-ready summary. Pure: the caller
    /// passes the scan and we re-derive everything from its relationships, so the sheet always
    /// reflects the current persisted state.
    static func summary(from scan: StoredScan) -> CleanupScanSummary {
        let categories = scan.cleanupActions
            .compactMap { action -> CleanupCategorySummary? in
                guard let kind = StorageFindingKind(rawValue: action.kindRaw) else { return nil }
                return CleanupCategorySummary(
                    kind: kind,
                    bytesReclaimed: action.bytesReclaimed,
                    itemCount: action.itemCount,
                    samplePaths: action.samplePaths
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
            totalBytesCleaned: totalBytes
        )
    }
}

private extension StorageFindingKind {
    /// Convenience mapping from a persisted cleanup kind to its UI `StorageDomain`. Mirrors the
    /// scan pipeline's mapping; if a kind has no canonical domain, fall back to `.otherCaches`.
    var defaultDomain: StorageDomain {
        switch self {
        case .xcodeArtifacts, .runtimeVersions: .appleDevelopment
        case .nodeDependencies, .browserCaches: .webDevelopment
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
        case .installerLeftovers: .leftovers
        case .orphanedAppSupport, .orphanedAppCaches, .orphanedAppContainers,
             .orphanedAppPreferences, .oldCrashReports: .systemJunk
        case .trash: .trash
        }
    }
}
