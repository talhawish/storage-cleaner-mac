import Foundation

struct DuplicateMediaScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let title: String
    private let domain: StorageDomain
    private let roots: [URL]
    private let extensions: Set<String>
    private let minimumBytes: Int64
    private let exclusionPolicy: DuplicateScanExclusionPolicy?
    private let collector: any FileTraversing
    /// When set, project-root detection is memoized here (once per root per
    /// scan) instead of each duplicate scanner re-walking the same trees.
    private let snapshotCache: DirectorySnapshotCache?
    private let builder: CandidateFindingBuilder

    init(
        kind: StorageFindingKind,
        domain: StorageDomain,
        roots: [URL],
        extensions: Set<String>,
        minimumBytes: Int64,
        exclusionPolicy: DuplicateScanExclusionPolicy? = nil,
        collector: any FileTraversing,
        snapshotCache: DirectorySnapshotCache? = nil,
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
        self.snapshotCache = snapshotCache
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let exclusionPolicy = await resolveExclusionPolicy()
        let result = await collector.collectMatchingFiles(
            at: roots,
            matching: { [extensions] record in
                extensions.contains(record.pathExtensionLowercased)
                    && !exclusionPolicy.shouldExclude(record.url)
            },
            limit: FileTraversalDefaults.fileLimit,
            prioritizeLargest: false
        )
        let groups = await DuplicateGrouper.groups(from: result.candidates, minimumBytes: minimumBytes)
        let finding = builder.makeDuplicateFinding(
            kind: kind,
            domain: domain,
            groups: groups,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: result.inspectedItemCount,
            message: finding == nil ? "No likely duplicate groups found" : "Found likely duplicates"
        )
    }

    private func resolveExclusionPolicy() async -> DuplicateScanExclusionPolicy {
        if let exclusionPolicy {
            return exclusionPolicy
        }
        guard let snapshotCache else {
            return DuplicateScanExclusionPolicy.detectingProjects(under: roots)
        }
        var detectedRoots: [URL] = []
        for root in roots {
            guard !Task.isCancelled else { break }
            detectedRoots += await snapshotCache.projectRoots(under: root)
        }
        return DuplicateScanExclusionPolicy(projectRoots: detectedRoots)
    }
}
