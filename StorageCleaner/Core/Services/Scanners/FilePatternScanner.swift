import Foundation

struct FilePatternScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let domain: StorageDomain
    private let roots: [URL]
    private let safety: CleanupSafety
    private let collector: FileSystemCollector
    private let matcher: @Sendable (URL) -> Bool
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        domain: StorageDomain,
        roots: [URL],
        safety: CleanupSafety,
        collector: FileSystemCollector,
        matcher: @escaping @Sendable (URL) -> Bool,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.kind = kind
        self.title = kind.title
        self.domain = domain
        self.roots = roots
        self.safety = safety
        self.collector = collector
        self.matcher = matcher
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let result = collector.collectFiles(at: roots, matching: matcher)
        let finding = builder.makeFinding(
            kind: kind,
            domain: domain,
            candidates: result.candidates,
            safety: safety
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: result.inspectedItemCount,
            message: finding == nil ? "No matching files found" : "Found \(result.candidates.count) candidates"
        )
    }
}
