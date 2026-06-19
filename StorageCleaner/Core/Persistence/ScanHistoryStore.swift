import Foundation
import SwiftData

/// A single cleanup action to be recorded in the audit history, scoped to one storage category.
struct CleanupAuditEntry: Sendable, Equatable {
    let kind: StorageFindingKind
    let bytesReclaimed: Int64
    let itemCount: Int
}

/// Persists scan results and cleanup audit records so the Cleanup History screen has data and
/// every destructive action leaves a durable trail (a core safety invariant).
///
/// `@MainActor` because the live implementation writes through SwiftData's main `ModelContext`,
/// which is the same context `@Query` reads from in `CleanupHistoryView`.
@MainActor
protocol ScanHistoryStore: AnyObject {
    /// Records a completed full scan and its findings.
    func recordCompletedScan(_ snapshot: ScanSnapshot)
    /// Records cleanup actions, attaching them to the most recent scan when one exists.
    func recordCleanupActions(_ entries: [CleanupAuditEntry])
}

@MainActor
final class SwiftDataScanHistoryStore: ScanHistoryStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func recordCompletedScan(_ snapshot: ScanSnapshot) {
        guard !snapshot.findings.isEmpty else { return }

        let scan = StoredScan(
            durationSeconds: snapshot.duration.totalSeconds,
            scannedItemCount: snapshot.scannedItemCount,
            reclaimableBytes: snapshot.reclaimableBytes,
            findings: snapshot.findings.map(StoredFinding.init(from:))
        )
        context.insert(scan)
        save()
    }

    func recordCleanupActions(_ entries: [CleanupAuditEntry]) {
        guard !entries.isEmpty else { return }

        let scan = mostRecentScan()
        for entry in entries {
            let action = StoredCleanupAction(
                kindRaw: entry.kind.rawValue,
                bytesReclaimed: entry.bytesReclaimed,
                itemCount: entry.itemCount
            )
            action.scan = scan
            context.insert(action)
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
