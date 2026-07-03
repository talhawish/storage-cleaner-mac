import Foundation

struct DuplicateMediaScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let domain: StorageDomain
    private let roots: [URL]
    private let extensions: Set<String>
    private let minimumBytes: Int64
    private let exclusionPolicy: DuplicateScanExclusionPolicy?
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        domain: StorageDomain,
        roots: [URL],
        extensions: Set<String>,
        minimumBytes: Int64,
        exclusionPolicy: DuplicateScanExclusionPolicy? = nil,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.kind = kind
        self.title = kind.title
        self.domain = domain
        self.roots = roots
        self.extensions = extensions
        self.minimumBytes = minimumBytes
        self.exclusionPolicy = exclusionPolicy
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let exclusionPolicy = exclusionPolicy ?? DuplicateScanExclusionPolicy.detectingProjects(under: roots)
        let result = collector.collectDuplicateGroups(
            at: roots,
            extensions: extensions,
            minimumBytes: minimumBytes,
            excluding: exclusionPolicy.shouldExclude
        )
        let finding = builder.makeDuplicateFinding(
            kind: kind,
            domain: domain,
            groups: result.groups,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: result.inspectedItemCount,
            message: finding == nil ? "No likely duplicate groups found" : "Found likely duplicates"
        )
    }
}
