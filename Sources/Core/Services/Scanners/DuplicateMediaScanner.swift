import Foundation

struct DuplicateMediaScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let domain: StorageDomain
    private let roots: [URL]
    private let extensions: Set<String>
    private let minimumBytes: Int64
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        domain: StorageDomain,
        roots: [URL],
        extensions: Set<String>,
        minimumBytes: Int64,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.kind = kind
        self.title = kind.title
        self.domain = domain
        self.roots = roots
        self.extensions = extensions
        self.minimumBytes = minimumBytes
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let candidates = collector.collectLikelyDuplicates(
            at: roots,
            extensions: extensions,
            minimumBytes: minimumBytes
        )
        let finding = builder.makeFinding(
            kind: kind,
            domain: domain,
            candidates: candidates,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: candidates.count,
            message: finding == nil ? "No likely duplicate groups found" : "Found likely duplicates"
        )
    }
}
