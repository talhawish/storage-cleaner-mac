import Foundation

struct PathListScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let domain: StorageDomain
    private let paths: [URL]
    private let safety: CleanupSafety
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        domain: StorageDomain,
        paths: [URL],
        safety: CleanupSafety,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.kind = kind
        self.title = kind.title
        self.domain = domain
        self.paths = paths
        self.safety = safety
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let candidates = collector.collectExistingItems(at: paths)
        let finding = builder.makeFinding(
            kind: kind,
            domain: domain,
            candidates: candidates,
            safety: safety
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: candidates.count,
            message: finding == nil ? "No matching folders found" : "Measured \(candidates.count) locations"
        )
    }
}
