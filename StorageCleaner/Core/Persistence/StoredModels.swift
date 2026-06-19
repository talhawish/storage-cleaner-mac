import Foundation
import SwiftData

@Model
final class StoredScan {
    var date: Date
    var durationSeconds: Double
    var scannedItemCount: Int
    var reclaimableBytes: Int64

    @Relationship(deleteRule: .cascade)
    var findings: [StoredFinding]

    @Relationship(deleteRule: .cascade)
    var cleanupActions: [StoredCleanupAction]

    init(
        date: Date = .now,
        durationSeconds: Double = 0,
        scannedItemCount: Int = 0,
        reclaimableBytes: Int64 = 0,
        findings: [StoredFinding] = [],
        cleanupActions: [StoredCleanupAction] = []
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.scannedItemCount = scannedItemCount
        self.reclaimableBytes = reclaimableBytes
        self.findings = findings
        self.cleanupActions = cleanupActions
    }
}

@Model
final class StoredFinding {
    var kindRaw: String
    var domainRaw: String
    var bytes: Int64
    var itemCount: Int
    var safetyRaw: String
    var examples: [String]
    var filePaths: [URL]
    /// JSON-encoded `[DuplicateGroup]`; non-nil only for duplicate findings. Optional so existing
    /// stores migrate without a value (SwiftData lightweight migration).
    var duplicateGroupsJSON: String?

    var scan: StoredScan?

    init(from finding: StorageFinding) {
        self.kindRaw = finding.kind.rawValue
        self.domainRaw = finding.domain.rawValue
        self.bytes = finding.bytes
        self.itemCount = finding.itemCount
        self.safetyRaw = finding.safety.rawValue
        self.examples = finding.examples
        self.filePaths = finding.filePaths
        self.duplicateGroupsJSON = finding.duplicateGroups.isEmpty
            ? nil
            : (try? JSONEncoder().encode(finding.duplicateGroups)).flatMap { String(data: $0, encoding: .utf8) }
    }

    var kind: StorageFindingKind? {
        StorageFindingKind(rawValue: kindRaw)
    }

    var domain: StorageDomain? {
        StorageDomain(rawValue: domainRaw)
    }

    var safety: CleanupSafety? {
        CleanupSafety(rawValue: safetyRaw)
    }

    func toStorageFinding() -> StorageFinding? {
        guard let kind, let domain, let safety else { return nil }
        let groups = duplicateGroupsJSON
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([DuplicateGroup].self, from: $0) } ?? []
        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: itemCount,
            safety: safety,
            examples: examples,
            filePaths: filePaths,
            duplicateGroups: groups
        )
    }
}

@Model
final class StoredCleanupAction {
    var date: Date
    var kindRaw: String
    var bytesReclaimed: Int64
    var itemCount: Int

    var scan: StoredScan?

    init(
        date: Date = .now,
        kindRaw: String = "",
        bytesReclaimed: Int64 = 0,
        itemCount: Int = 0
    ) {
        self.date = date
        self.kindRaw = kindRaw
        self.bytesReclaimed = bytesReclaimed
        self.itemCount = itemCount
    }
}
