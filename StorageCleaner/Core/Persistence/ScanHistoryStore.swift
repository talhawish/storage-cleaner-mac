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
    /// Deletes every stored scan (and, via cascade, its findings and cleanup
    /// actions). Backs the History screen's "Clear History" action.
    func clearHistory()
    /// Human-readable description of the most recent persistence failure, or
    /// `nil` when every write has landed. Lets the UI warn that the audit
    /// trail is incomplete instead of losing records silently.
    var lastPersistenceError: String? { get }
}

extension ScanHistoryStore {
    func clearHistory() {}
    var lastPersistenceError: String? { nil }
}

@MainActor
@Observable
final class SwiftDataScanHistoryStore: ScanHistoryStore {
    @ObservationIgnored private let context: ModelContext
    /// Injected save so tests can exercise the failure path — SwiftData's
    /// `ModelContext.save()` cannot be made to throw on demand.
    @ObservationIgnored private let performSave: (ModelContext) throws -> Void
    private(set) var lastPersistenceError: String?

    /// Newest scans kept on disk. Every full scan persists all findings
    /// (including file-path arrays), so an uncapped store grows without bound
    /// over months of use; 50 scans is months of history at typical usage.
    static let maxStoredScans = 50

    /// Serial chain of pending persistence work. Each write awaits the
    /// previous one, preserving scan-then-cleanup ordering while the heavy
    /// payload encoding runs off the main actor.
    @ObservationIgnored private var pendingWork: Task<Void, Never>?

    init(
        context: ModelContext,
        performSave: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.context = context
        self.performSave = performSave
    }

    func recordCompletedScan(_ snapshot: ScanSnapshot, disk: ScanDiskSnapshot) {
        guard !snapshot.findings.isEmpty else { return }

        enqueue { store in
            // Encoding pathBytes/duplicateGroups for a full scan serializes
            // thousands of URLs — do it on a detached task so results landing
            // never hitch the UI.
            let findings = snapshot.findings
            let payloads = await Task.detached(priority: .utility) {
                findings.map(StoredFindingPayload.init(from:))
            }.value
            store.insertScan(payloads: payloads, snapshot: snapshot, disk: disk)
        }
    }

    func recordCleanupActions(_ entries: [CleanupAuditEntry], disk: ScanDiskSnapshot) {
        let entries = sanitizedEntries(from: entries)
        guard !entries.isEmpty else { return }

        enqueue { store in
            store.insertCleanupActions(entries: entries, disk: disk)
        }
    }

    func clearHistory() {
        enqueue { store in
            store.deleteAllScans()
        }
    }

    /// Awaits all queued persistence work. Test seam — production code never
    /// needs to block on history writes.
    func flush() async {
        await pendingWork?.value
    }

    private func enqueue(_ work: @escaping @MainActor (SwiftDataScanHistoryStore) async -> Void) {
        pendingWork = Task { [weak self, previous = pendingWork] in
            await previous?.value
            guard let self else { return }
            await work(self)
        }
    }

    private func insertScan(
        payloads: [StoredFindingPayload],
        snapshot: ScanSnapshot,
        disk: ScanDiskSnapshot
    ) {
        let scan = StoredScan(
            durationSeconds: snapshot.duration.totalSeconds,
            scannedItemCount: snapshot.scannedItemCount,
            reclaimableBytes: snapshot.reclaimableBytes,
            volumeTotalBytes: disk.totalBytes,
            freeBytesBefore: disk.freeBytes,
            findings: payloads.map(StoredFinding.init(payload:))
        )
        context.insert(scan)
        enforceRetention()
        save()
    }

    private func insertCleanupActions(entries: [CleanupAuditEntry], disk: ScanDiskSnapshot) {
        let scan = mostRecentScan() ?? createCleanupOnlyScan(disk: disk)
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
        scan.cleanedBytes = saturatedAdd(scan.cleanedBytes, newBytes)
        if disk.isAvailable {
            scan.freeBytesAfter = disk.freeBytes
        }
        save()
    }

    /// Drops the oldest scans past `maxStoredScans`; cascade deletes remove
    /// their findings and cleanup actions.
    private func enforceRetention() {
        let descriptor = FetchDescriptor<StoredScan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let scans = try? context.fetch(descriptor), scans.count > Self.maxStoredScans else { return }
        for stale in scans.dropFirst(Self.maxStoredScans) {
            context.delete(stale)
        }
    }

    /// Individual deletes (not a batch delete) so SwiftData's cascade rules
    /// reliably remove findings and actions on every supported macOS version.
    private func deleteAllScans() {
        let scans = (try? context.fetch(FetchDescriptor<StoredScan>())) ?? []
        for scan in scans {
            context.delete(scan)
        }
        save()
    }

    private static let samplePathLimit = 5

    private func sanitizedEntries(from entries: [CleanupAuditEntry]) -> [CleanupAuditEntry] {
        entries.compactMap { entry in
            guard entry.itemCount > 0, entry.bytesReclaimed >= 0 else { return nil }
            return CleanupAuditEntry(
                kind: entry.kind,
                bytesReclaimed: entry.bytesReclaimed,
                itemCount: entry.itemCount,
                samplePaths: Self.samplePaths(from: entry.samplePaths)
            )
        }
    }

    private func mostRecentScan() -> StoredScan? {
        var descriptor = FetchDescriptor<StoredScan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func createCleanupOnlyScan(disk: ScanDiskSnapshot) -> StoredScan {
        let scan = StoredScan(
            durationSeconds: 0,
            scannedItemCount: 0,
            reclaimableBytes: 0,
            volumeTotalBytes: disk.totalBytes,
            freeBytesBefore: 0,
            freeBytesAfter: disk.isAvailable ? disk.freeBytes : 0,
            findings: []
        )
        context.insert(scan)
        return scan
    }

    private static func samplePaths<S: Sequence>(from paths: S) -> [URL] where S.Element == URL {
        var seen = Set<String>()
        var samples: [URL] = []
        for path in paths {
            let normalizedPath = path.normalizedFilesystemPath
            guard seen.insert(normalizedPath).inserted else { continue }
            samples.append(path)
            if samples.count == samplePathLimit { break }
        }
        return samples
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
    /// cleanup. Failures stay non-fatal, but they are logged and surfaced through
    /// `lastPersistenceError` so the user can learn the audit trail is incomplete.
    private func save() {
        do {
            try performSave(context)
            lastPersistenceError = nil
        } catch {
            AppLog.persistence.error("Failed to save scan history: \(error.localizedDescription)")
            lastPersistenceError = error.localizedDescription
        }
    }
}

private extension Duration {
    var totalSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1_000_000_000_000_000_000
    }
}
