import Foundation

/// Surfaces runtimes with multiple installed versions as a `.runtimeVersions` finding so the
/// Overview and the dynamic sidebar reflect how much can be reclaimed by removing older versions.
///
/// The finding's `bytes`/`filePaths` describe only the **older** (removable) versions — the newest
/// of each runtime is always kept — so the dashboard's reclaim estimate stays correct. The grouped
/// `RuntimeVersionsView` does its own discovery, so this scanner is purely for headline numbers.
struct RuntimeVersionScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .runtimeVersions
    let title = StorageFindingKind.runtimeVersions.title
    private let environment: RuntimeVersionCatalog.Environment

    init(environment: RuntimeVersionCatalog.Environment = .live) {
        self.environment = environment
    }

    func scan() async -> CategoryScanResult {
        let groups = RuntimeVersionCatalog.measured(
            RuntimeVersionCatalog.discoverGroups(environment: environment)
        )
        let removable = groups.flatMap(\.olderItems)
        let bytes = removable.reduce(Int64(0)) { $0 + $1.bytes }
        let inspected = groups.reduce(0) { $0 + $1.items.count }

        guard bytes > 0, !removable.isEmpty else {
            return CategoryScanResult(
                finding: nil,
                inspectedItemCount: inspected,
                message: "No duplicate runtime versions"
            )
        }

        let finding = StorageFinding(
            kind: .runtimeVersions,
            domain: .cliTooling,
            bytes: bytes,
            itemCount: removable.count,
            safety: .review,
            examples: Array(groups.prefix(3).map { "\($0.runtime.title): \($0.olderItems.count) older" }),
            filePaths: removable.map(\.url)
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: inspected,
            message: "\(removable.count) older versions across \(groups.count) runtimes"
        )
    }
}
