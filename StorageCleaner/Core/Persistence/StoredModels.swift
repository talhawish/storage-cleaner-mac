import Foundation
import SwiftData

@Model
final class StoredScan {
    var date: Date
    var durationSeconds: Double
    var scannedItemCount: Int
    var reclaimableBytes: Int64
    /// Sum of bytes reclaimed by every `cleanupActions` entry attached to this scan. Computed at
    /// write time so the Cleanup History totals stay cheap and don't drift if action ordering or
    /// re-runs leave stale rows behind. Defaults to 0 so existing stores migrate cleanly.
    var cleanedBytes: Int64
    /// Total capacity of the volume the user is on, captured when the scan
    /// started. `0` when the volume attributes couldn't be read (older scans
    /// migrated from a pre-disk-tracking build, or sandboxed environments
    /// without the necessary entitlement).
    var volumeTotalBytes: Int64
    /// Free space on the volume at the moment the scan started. Combined with
    /// `volumeTotalBytes` it powers the "X free before, Y after" pill on
    /// `HistoryScanCard` and the home screen's status card.
    var freeBytesBefore: Int64
    /// Free space on the volume after every cleanup action attached to this
    /// scan has run. `0` when no cleanup ran on this scan (e.g. the user only
    /// scanned and never deleted anything, or the volume attributes couldn't
    /// be re-read after the cleanup).
    var freeBytesAfter: Int64

    @Relationship(deleteRule: .cascade)
    var findings: [StoredFinding]

    @Relationship(deleteRule: .cascade)
    var cleanupActions: [StoredCleanupAction]

    init(
        date: Date = .now,
        durationSeconds: Double = 0,
        scannedItemCount: Int = 0,
        reclaimableBytes: Int64 = 0,
        cleanedBytes: Int64 = 0,
        volumeTotalBytes: Int64 = 0,
        freeBytesBefore: Int64 = 0,
        freeBytesAfter: Int64 = 0,
        findings: [StoredFinding] = [],
        cleanupActions: [StoredCleanupAction] = []
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.scannedItemCount = scannedItemCount
        self.reclaimableBytes = reclaimableBytes
        self.cleanedBytes = cleanedBytes
        self.volumeTotalBytes = volumeTotalBytes
        self.freeBytesBefore = freeBytesBefore
        self.freeBytesAfter = freeBytesAfter
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
    var pathBytesJSON: String?

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
        self.pathBytesJSON = finding.pathBytes.isEmpty
            ? nil
            : (try? JSONEncoder().encode(finding.pathBytes)).flatMap { String(data: $0, encoding: .utf8) }
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
        let pathBytes = pathBytesJSON
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([URL: Int64].self, from: $0) } ?? [:]
        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: itemCount,
            safety: safety,
            examples: examples,
            filePaths: filePaths,
            pathBytes: pathBytes,
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
    /// A handful of representative original paths that were moved to Trash. Persisted as URLs so
    /// the Cleanup History detail sheet can offer "Show in Finder" without re-scanning disk.
    var samplePaths: [URL]

    var scan: StoredScan?

    init(
        date: Date = .now,
        kindRaw: String = "",
        bytesReclaimed: Int64 = 0,
        itemCount: Int = 0,
        samplePaths: [URL] = []
    ) {
        self.date = date
        self.kindRaw = kindRaw
        self.bytesReclaimed = bytesReclaimed
        self.itemCount = itemCount
        self.samplePaths = samplePaths
    }
}
