import XCTest
@testable import StorageCleaner

/// Covers `DashboardViewModel`'s snapshot-derived Overview accessors. Kept separate from
/// `DashboardViewModelTests` so neither file exceeds the line-length limit.
@MainActor
final class DashboardViewModelOverviewTests: XCTestCase {
    private func finding(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        items: Int,
        safety: CleanupSafety
    ) -> StorageFinding {
        StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: items,
            safety: safety,
            examples: [],
            filePaths: []
        )
    }

    func testOverviewAccessorsAggregateSnapshot() async {
        let snapshot = ScanSnapshot(
            findings: [
                finding(.xcodeArtifacts, .appleDevelopment, bytes: 80, items: 3, safety: .safe),
                finding(.nodeDependencies, .webDevelopment, bytes: 20, items: 1, safety: .safe),
                finding(.largeVideos, .media, bytes: 40, items: 2, safety: .review)
            ],
            scannedItemCount: 6,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: OverviewFixedScanner(snapshot: snapshot),
            permissionHandler: OverviewStubPermissionHandler()
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(
            viewModel.domainGroups.map(\.domain),
            [.appleDevelopment, .media, .webDevelopment]
        )
        XCTAssertEqual(viewModel.safeReclaimableBytes, 100)
        XCTAssertEqual(viewModel.reviewReclaimableBytes, 40)
        XCTAssertEqual(viewModel.finding(for: .largeVideos)?.bytes, 40)

        // Biggest safe win is Xcode (80 > 20); review-only media is excluded from the win.
        let tipIDs = viewModel.overviewTips.map(\.id)
        XCTAssertTrue(tipIDs.contains("quick-win"))
        XCTAssertTrue(tipIDs.contains("safe-review"))
        XCTAssertEqual(
            viewModel.overviewTips.first { $0.id == "quick-win" }?.action,
            .reveal(.xcodeArtifacts)
        )
    }
}

private struct OverviewFixedScanner: StorageScanning {
    let snapshot: ScanSnapshot

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(.completed(snapshot))
            continuation.finish()
        }
    }
}

private final class OverviewStubPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] {
        StoragePermissionScope.allCases.map { scope in
            StoragePermissionStatus(
                scope: scope,
                url: URL(filePath: "/Users/test/\(scope.rawValue)"),
                state: .accessible
            )
        }
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        // Stub token — the test scanner doesn't touch the filesystem,
        // and the dashboard's `ensureAccessAvailable()` only needs a
        // non-nil access probe to know it can proceed.
        SecurityScopedResourceAccess(
            url: URL(filePath: "/tmp/stub"),
            didStartAccessing: false
        )
    }
}
