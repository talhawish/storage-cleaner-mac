import Foundation
import SwiftData

/// A single cleanup action to be recorded in the audit history, scoped to one storage category.
struct CleanupAuditEntry: Sendable, Equatable {
    let kind: StorageFindingKind
    let bytesReclaimed: Int64
    let itemCount: Int
    /// Up to a small number of representative original paths that were removed, so the Cleanup
    /// History row can show *what* was deleted and offer "Show in Finder". Truncated at the call
    /// site to avoid bloating the audit log.
    let samplePaths: [URL]

    init(
        kind: StorageFindingKind,
        bytesReclaimed: Int64,
        itemCount: Int,
        samplePaths: [URL] = []
    ) {
        self.kind = kind
        self.bytesReclaimed = bytesReclaimed
        self.itemCount = itemCount
        self.samplePaths = samplePaths
    }
}

/// Optional disk-space metadata captured at scan time. Both snapshots are
/// expected to come from the same `DiskSpaceReading` implementation so the
/// numbers are directly comparable. `totalBytes` is `0` when the volume
/// attributes couldn't be read — `StoredScan` stores all three fields as
/// `Int64` and the Cleanup History card hides the disk pill when the total
/// is `0`.
struct ScanDiskSnapshot: Sendable, Equatable {
    let totalBytes: Int64
    let freeBytes: Int64

    init(totalBytes: Int64, freeBytes: Int64) {
        self.totalBytes = max(0, totalBytes)
        self.freeBytes = max(0, freeBytes)
    }

    static let unavailable = ScanDiskSnapshot(totalBytes: 0, freeBytes: 0)
    var isAvailable: Bool { totalBytes > 0 }

    func snapshot() -> VolumeSnapshot {
        VolumeSnapshot(
            totalBytes: totalBytes,
            usedBytes: max(0, totalBytes - freeBytes),
            freeBytes: freeBytes
        )
    }
}

/// Persists scan results and cleanup audit records so the Cleanup History screen has data and
/// every destructive action leaves a durable trail (a core safety invariant).
///
/// `@MainActor` because the live implementation writes through SwiftData's main `ModelContext`,
/// which is the same context `@Query` reads from in `CleanupHistoryView`.
@MainActor
protocol ScanHistoryStore: AnyObject {
    /// Records a completed full scan and its findings, optionally including a
    /// disk-space snapshot taken when the scan started. The disk snapshot
    /// feeds the "X free before cleanup" call-out on the Cleanup History row.
    func recordCompletedScan(_ snapshot: ScanSnapshot, disk: ScanDiskSnapshot)
    /// Records cleanup actions, attaching them to the most recent scan when one exists. The
    /// optional `disk` argument captures the volume's free-bytes *after* the cleanup so the
    /// Cleanup History row can render "X was free before, Y is free after" without a follow-up
    /// `statfs` roundtrip.
    func recordCleanupActions(_ entries: [CleanupAuditEntry], disk: ScanDiskSnapshot)
}

@MainActor
final class SwiftDataScanHistoryStore: ScanHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recordCompletedScan(_ snapshot: ScanSnapshot, disk: ScanDiskSnapshot) {
        guard !snapshot.findings.isEmpty else { return }

        let scan = StoredScan(
            durationSeconds: snapshot.duration.totalSeconds,
            scannedItemCount: snapshot.scannedItemCount,
            reclaimableBytes: snapshot.reclaimableBytes,
            volumeTotalBytes: disk.totalBytes,
            freeBytesBefore: disk.freeBytes,
            findings: snapshot.findings.map(StoredFinding.init(from:))
        )
        context.insert(scan)
        save()
    }

    func recordCleanupActions(_ entries: [CleanupAuditEntry], disk: ScanDiskSnapshot) {
        guard !entries.isEmpty else { return }

        let scan = mostRecentScan()
        let newBytes = saturatedCleanupTotal(for: entries)
        for entry in entries {
            let action = StoredCleanupAction(
                kindRaw: entry.kind.rawValue,
                bytesReclaimed: entry.bytesReclaimed,
                itemCount: entry.itemCount,
                samplePaths: entry.samplePaths.isEmpty ? nil : entry.samplePaths
            )
            action.scan = scan
            context.insert(action)
        }
        // Update the scan's running total in-place so the Cleanup History row can read a
        // single field for the "storage recovered" call-out without re-summing actions.
        if let scan {
            scan.cleanedBytes = saturatedAdd(scan.cleanedBytes, newBytes)
            if disk.isAvailable {
                scan.freeBytesAfter = disk.freeBytes
            }
        }
        save()
    }

    private func mostRecentScan() -> StoredScan? {
        var descriptor = FetchDescriptor<StoredScan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func saturatedCleanupTotal(for entries: [CleanupAuditEntry]) -> Int64 {
        entries.reduce(Int64(0)) { total, entry in
            saturatedAdd(total, max(0, entry.bytesReclaimed))
        }
    }

    private func saturatedAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = max(0, lhs).addingReportingOverflow(max(0, rhs))
        return overflow ? .max : sum
    }

    /// Audit records are best-effort: a persistence failure must never crash the app or block
    /// cleanup. Failures are intentionally non-fatal here.
    private func save() {
        try? context.save()
    }
}

private extension Duration {
    var totalSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}
