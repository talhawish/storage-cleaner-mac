import Foundation

struct PHPDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .phpDependencies
    let title = StorageFindingKind.phpDependencies.title
    private let cachePaths: [URL]
    private let projectRoots: [URL]
    private let maxProjectDependencyDepth: Int
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        cachePaths: [URL] = DependencyPaths.PHP.cacheDirs,
        projectRoots: [URL] = DependencyPaths.Projects.searchRoots,
        maxProjectDependencyDepth: Int = DependencyPaths.PHP.projectVendorMaxDepth,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.cachePaths = cachePaths
        self.projectRoots = projectRoots
        self.maxProjectDependencyDepth = maxProjectDependencyDepth
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let cacheResult = collector.collectExistingItems(at: cachePaths)
        let vendorResult = collector.collectDirectories(
            at: projectRoots,
            matching: { ProjectDependencyRules.isComposerVendorDirectory($0) },
            maxDepth: maxProjectDependencyDepth
        )
        let candidates = Self.deduplicate(cacheResult.candidates + vendorResult.candidates)
        let finding = builder.makeFinding(
            kind: kind,
            domain: .webDevelopment,
            candidates: candidates,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: cacheResult.inspectedItemCount + vendorResult.inspectedItemCount,
            message: finding == nil
                ? "No Composer dependencies found"
                : "Measured \(candidates.count) Composer locations"
        )
    }

    private static func deduplicate(_ candidates: [FileCandidate]) -> [FileCandidate] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            seen.insert(candidate.url.standardizedFileURL.path).inserted
        }
    }
}
