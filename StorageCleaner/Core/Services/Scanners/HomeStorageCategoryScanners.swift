import Foundation

/// Finds large user-home folders that do not belong to a focused storage category.
/// Unknown data always requires review; this scanner never marks it safe to remove.
struct LargeFolderScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .largeFolders
    let title = StorageFindingKind.largeFolders.title
    private let discoveryCache: HomeStorageDiscoveryCache
    private let builder = CandidateFindingBuilder()

    init(discoveryCache: HomeStorageDiscoveryCache) {
        self.discoveryCache = discoveryCache
    }

    func scan() async -> CategoryScanResult {
        let report = await discoveryCache.discover()
        let result = report.result
        let finding = builder.makeFinding(
            kind: kind,
            domain: .otherCaches,
            candidates: result.largeFolders,
            safety: .review
        )
        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: report.inspectedItemCount,
            message: finding == nil
                ? "No unclassified folders over the size threshold in accessible locations"
                : "Found \(result.largeFolders.count) large folders to review" + result.accessSummary
        )
    }
}

/// Finds model-weight files by on-disk format throughout Home, independent of
/// the application that installed them. Known model-store roots stay represented
/// by `AIModelCacheScanner`, avoiding duplicate accounting.
struct LocalAIModelScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .localAIModels
    let title = StorageFindingKind.localAIModels.title
    private let discoveryCache: HomeStorageDiscoveryCache
    private let builder = CandidateFindingBuilder()

    init(discoveryCache: HomeStorageDiscoveryCache) {
        self.discoveryCache = discoveryCache
    }

    func scan() async -> CategoryScanResult {
        let report = await discoveryCache.discover()
        let result = report.result
        let finding = builder.makeFinding(
            kind: kind,
            domain: .artificialIntelligence,
            candidates: result.localAIModels,
            safety: .review
        )
        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: report.inspectedItemCount,
            message: finding == nil
                ? "No local model files over the size threshold in accessible locations"
                : "Found \(result.localAIModels.count) local model files to review" + result.accessSummary
        )
    }
}

extension HomeStorageDiscoveryResult {
    var accessSummary: String {
        unreadableItemCount > 0 ? " · \(unreadableItemCount) unreadable locations skipped" : ""
    }
}
