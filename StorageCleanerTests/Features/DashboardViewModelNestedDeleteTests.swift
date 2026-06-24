import XCTest
@testable import StorageCleaner

@MainActor
final class DashboardViewModelNestedDeleteTests: XCTestCase {
    func testDeletingNestedPathPrunesParentFindingBytesAndAudit() async {
        let parent = URL(filePath: "/tmp/DerivedData")
        let child = parent.appending(path: "ProjectBuild", directoryHint: .isDirectory)
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .xcodeArtifacts,
                    domain: .appleDevelopment,
                    bytes: 100,
                    itemCount: 1,
                    safety: .safe,
                    examples: [],
                    filePaths: [parent]
                )
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
        let store = NestedDeleteSpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: NestedDeleteFixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: NestedDeletePermissionHandler(),
            cleanupService: NestedDeleteCleanupService(reclaimedBytesByURL: [child: 40]),
            historyStore: store
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([child])

        XCTAssertEqual(store.recordedCleanups.first, [
            CleanupAuditEntry(kind: .xcodeArtifacts, bytesReclaimed: 40, itemCount: 1, samplePaths: [child])
        ])
        let finding = viewModel.snapshot?.findings.first
        XCTAssertEqual(finding?.filePaths, [parent])
        XCTAssertEqual(finding?.bytes, 60)
        XCTAssertEqual(finding?.itemCount, 1)
    }
}

private struct NestedDeleteFixedSnapshotScanner: StorageScanning {
    let snapshot: ScanSnapshot

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(.completed(snapshot))
            continuation.finish()
        }
    }
}

private struct NestedDeletePermissionHandler: StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] {
        StoragePermissionScope.allCases.map { scope in
            StoragePermissionStatus(
                scope: scope,
                url: URL(filePath: "/Users/test/\(scope.rawValue)"),
                state: .accessible
            )
        }
    }
}

private struct NestedDeleteCleanupService: CleanupService {
    let reclaimedBytesByURL: [URL: Int64]

    func delete(urls: [URL]) async -> CleanupResult {
        let items = urls.map { DeletedItem(originalURL: $0, bytesReclaimed: reclaimedBytesByURL[$0] ?? 0) }
        let trash = urls.map { URL(filePath: "/tmp/Trash/\($0.lastPathComponent)") }
        let total = items.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        return CleanupResult(deletedURLs: trash, deletedItems: items, failedURLs: [], totalBytesReclaimed: total)
    }
}

@MainActor
private final class NestedDeleteSpyHistoryStore: ScanHistoryStore {
    private(set) var recordedCleanups: [[CleanupAuditEntry]] = []

    func recordCompletedScan(_ snapshot: ScanSnapshot, disk: ScanDiskSnapshot) {}

    func recordCleanupActions(_ entries: [CleanupAuditEntry], disk: ScanDiskSnapshot) {
        recordedCleanups.append(entries)
    }
}
