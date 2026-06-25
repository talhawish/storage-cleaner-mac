import XCTest
@testable import StorageCleaner

private enum StubAccessMode: Sendable {
    case consistentWithStatus
    case alwaysGrant
    case alwaysDeny
}

final class StubPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    var statuses: [StoragePermissionStatus]
    /// How `beginHomeFolderAccess()` should resolve. Defaults to
    /// `.consistentWithStatus` — i.e. access is granted iff every
    /// reported status is `.accessible`. Tests that need a stale
    /// bookmark or an unconditional grant opt in explicitly.
    private var accessMode: StubAccessMode = .consistentWithStatus

    init(statuses: [StoragePermissionStatus]) {
        self.statuses = statuses
    }

    func currentStatuses() -> [StoragePermissionStatus] {
        statuses
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        let grantsAccess: Bool
        switch accessMode {
        case .alwaysGrant:
            grantsAccess = true
        case .alwaysDeny:
            grantsAccess = false
        case .consistentWithStatus:
            grantsAccess = statuses.allSatisfy { $0.state == .accessible }
        }
        guard grantsAccess else { return nil }
        // No real URL is started — the stub token is enough to satisfy
        // the dashboard's `ensureAccessAvailable()` probe; the test's
        // scanner stub doesn't actually touch the filesystem.
        return SecurityScopedResourceAccess(url: URL(filePath: "/tmp/stub"), didStartAccessing: false)
    }

    /// Test seam: opt into a stale-bookmark scenario where
    /// `currentStatuses()` reports `.accessible` but the access probe
    /// denies access. Used by the new dashboard regression test.
    func simulateStaleBookmark() {
        accessMode = .alwaysDeny
    }
}

let allAccessibleStatuses: [StoragePermissionStatus] =
    StoragePermissionScope.allCases.map { scope in
        StoragePermissionStatus(
            scope: scope,
            url: URL(filePath: "/Users/test/\(scope.rawValue)"),
            state: .accessible
        )
    }

struct DelayedScanner: StorageScanning {
    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .seconds(10))
                continuation.yield(.completed(snapshot))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private var snapshot: ScanSnapshot {
        ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .largeVideos,
                    domain: .media,
                    bytes: 10,
                    itemCount: 1,
                    safety: .review,
                    examples: ["Screen recordings"],
                    filePaths: []
                )
            ],
            scannedItemCount: 1,
            duration: .seconds(10)
        )
    }
}

final class RecordingScanner: @unchecked Sendable, StorageScanning {
    var requestedKinds: Set<StorageFindingKind>?
    var snapshot = ScanSnapshot(
        findings: [
            StorageFinding(
                kind: .screenshots,
                domain: .screenshots,
                bytes: 10,
                itemCount: 1,
                safety: .review,
                examples: [],
                filePaths: []
            )
        ],
        scannedItemCount: 1,
        duration: .seconds(1)
    )

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        requestedKinds = kinds
        return AsyncStream { continuation in
            continuation.yield(.completed(snapshot))
            continuation.finish()
        }
    }
}

struct FixedSnapshotScanner: StorageScanning {
    let snapshot: ScanSnapshot

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(.completed(snapshot))
            continuation.finish()
        }
    }
}

struct StubCleanupService: CleanupService {
    let reclaimedBytesByURL: [URL: Int64]

    func delete(urls: [URL]) async -> CleanupResult {
        let items = urls.map { DeletedItem(originalURL: $0, bytesReclaimed: reclaimedBytesByURL[$0] ?? 0) }
        let trash = urls.map { URL(filePath: "/tmp/Trash/\($0.lastPathComponent)") }
        let total = items.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        return CleanupResult(deletedURLs: trash, deletedItems: items, failedURLs: [], totalBytesReclaimed: total)
    }
}

@MainActor
final class SpyHistoryStore: ScanHistoryStore {
    private(set) var recordedScans: [ScanSnapshot] = []
    private(set) var recordedScanDisks: [ScanDiskSnapshot] = []
    private(set) var recordedCleanups: [[CleanupAuditEntry]] = []
    private(set) var recordedCleanupDisks: [ScanDiskSnapshot] = []

    func recordCompletedScan(_ snapshot: ScanSnapshot, disk: ScanDiskSnapshot) {
        recordedScans.append(snapshot)
        recordedScanDisks.append(disk)
    }

    func recordCleanupActions(_ entries: [CleanupAuditEntry], disk: ScanDiskSnapshot) {
        recordedCleanups.append(entries)
        recordedCleanupDisks.append(disk)
    }
}

struct ImmediateScanner: StorageScanning {
    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(.completed(snapshot))
            continuation.finish()
        }
    }

    private var snapshot: ScanSnapshot {
        ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .largeVideos,
                    domain: .media,
                    bytes: 10,
                    itemCount: 1,
                    safety: .review,
                    examples: ["Screen recordings"],
                    filePaths: []
                )
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
    }
}

struct EmptyStreamScanner: StorageScanning {
    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
