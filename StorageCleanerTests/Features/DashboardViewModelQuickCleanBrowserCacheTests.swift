import XCTest
@testable import StorageCleaner

/// End-to-end coverage for the Quick Clean → browser cache → Cleanup History
/// pipeline. The dashboard scanner, the Quick Clean modal, and the cleanup
/// audit must cooperate so a browser-cache cleanup always leaves a permanent
/// `.browserCaches` record — whether the user ran a scan first or not.
///
/// `CleanupOptionsRegistry.storageKind(forURL:)` resolves kinds by string
/// prefix against the registered paths, so the URLs in these tests don't
/// need to exist on disk — only to match a registered path string.
@MainActor
final class QuickCleanBrowserCacheTests: XCTestCase {
    // MARK: - Fixtures

    /// A synthetic URL that lives inside a real registered browser cache
    /// root. Used as the "deleted URL" in every test so the audit lookup
    /// resolves to `.browserCaches` regardless of whether anything actually
    /// exists on disk.
    private static let safariChild: URL = {
        guard let root = DependencyPaths.Browser.cacheDirs
            .first(where: { $0.lastPathComponent == "com.apple.Safari" }) else {
            fatalError("Test fixture: registered browser cache paths are missing the Safari entry")
        }
        return root.appending(path: "scratch-test", directoryHint: .notDirectory)
    }()

    private var safariChild: URL { Self.safariChild }

    /// Builds a `DashboardViewModel` whose scanner returns `snapshot` and whose
    /// cleanup service moves `urls` to Trash, reporting `reclaimedBytesByURL`
    /// for each.
    private func makeViewModel(
        snapshot: ScanSnapshot?,
        reclaimedBytesByURL: [URL: Int64]
    ) -> (DashboardViewModel, SpyHistoryStore) {
        let scanner: any StorageScanning = snapshot.map(FixedSnapshotScanner.init(snapshot:))
            ?? EmptySnapshotScanner()
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: scanner,
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: reclaimedBytesByURL),
            historyStore: store
        )
        return (viewModel, store)
    }

    // MARK: - With prior scan

    /// A Quick Clean cleanup of a URL that the dashboard scan already knows
    /// about must (a) write a `.browserCaches` audit entry attributed to the
    /// finding, and (b) prune the URL + bytes from the finding.
    func testDeleteBrowserCacheURLWithPriorScanPrunesFindingAndWritesAudit() async {
        guard let chromiumRoot = DependencyPaths.Browser.cacheDirs
            .first(where: { $0.lastPathComponent == "Chromium" }) else {
            return XCTFail("Registered browser cache paths are missing the Chromium entry")
        }
        let other = chromiumRoot.appending(path: "scratch-other", directoryHint: .isDirectory)

        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .browserCaches,
                    domain: .browserData,
                    bytes: 200,
                    itemCount: 2,
                    safety: .safe,
                    examples: ["Safari", "other"],
                    filePaths: [safariChild, other],
                    pathBytes: [safariChild: 120, other: 80]
                )
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )
        let (viewModel, store) = makeViewModel(
            snapshot: snapshot,
            reclaimedBytesByURL: [safariChild: 120]
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([safariChild])

        XCTAssertEqual(store.recordedCleanups.count, 1)
        XCTAssertEqual(
            store.recordedCleanups.first,
            [CleanupAuditEntry(
                kind: .browserCaches,
                bytesReclaimed: 120,
                itemCount: 1,
                samplePaths: [safariChild]
            )]
        )
        let finding = viewModel.snapshot?.findings.first
        XCTAssertEqual(finding?.filePaths, [other])
        XCTAssertEqual(finding?.bytes, 80)
        XCTAssertEqual(finding?.itemCount, 1)
        XCTAssertEqual(finding?.pathBytes, [other: 80])
    }

    // MARK: - Without prior scan

    /// The original bug: a Quick Clean cleanup that runs before the user has
    /// ever started a scan must still leave a `.browserCaches` audit entry.
    /// Without the `CleanupOptionsRegistry` fallback the audit would be silent
    /// and the user would have no record of what they cleaned.
    func testDeleteBrowserCacheURLWithNoPriorScanStillWritesAudit() async {
        let (viewModel, store) = makeViewModel(
            snapshot: nil,
            reclaimedBytesByURL: [safariChild: 50]
        )

        _ = await viewModel.deleteFiles([safariChild])

        XCTAssertEqual(store.recordedCleanups.count, 1)
        XCTAssertEqual(
            store.recordedCleanups.first,
            [CleanupAuditEntry(
                kind: .browserCaches,
                bytesReclaimed: 50,
                itemCount: 1,
                samplePaths: [safariChild]
            )]
        )
        // No prior snapshot means there's nothing to prune — but the audit
        // must still fire.
        XCTAssertNil(viewModel.snapshot)
    }

    /// When the snapshot exists but covers a different finding, a Quick Clean
    /// delete of an untracked URL must fall back to the option registry and
    /// produce the right audit kind (without touching the unrelated finding).
    func testDeleteUntrackedURLFallsBackToOptionRegistry() async {
        let unrelated = URL(fileURLWithPath: "/tmp/scratch-unrelated", isDirectory: true)
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .junkFiles,
                    domain: .otherCaches,
                    bytes: 100,
                    itemCount: 1,
                    safety: .safe,
                    examples: ["Unrelated"],
                    filePaths: [unrelated]
                )
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
        let (viewModel, store) = makeViewModel(
            snapshot: snapshot,
            reclaimedBytesByURL: [safariChild: 30]
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([safariChild])

        XCTAssertEqual(store.recordedCleanups.count, 1)
        XCTAssertEqual(
            store.recordedCleanups.first,
            [CleanupAuditEntry(
                kind: .browserCaches,
                bytesReclaimed: 30,
                itemCount: 1,
                samplePaths: [safariChild]
            )]
        )
        // The unrelated finding must be untouched.
        let finding = viewModel.snapshot?.findings.first
        XCTAssertEqual(finding?.kind, .junkFiles)
        XCTAssertEqual(finding?.bytes, 100)
    }
}

// MARK: - Test doubles

/// Scanner that always returns an empty snapshot (i.e. behaves as if the
/// user never ran a scan). Distinct from the production scanners so a
/// misconfigured test can never accidentally read a real finding list.
private struct EmptySnapshotScanner: StorageScanning {
    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(
                .completed(
                    ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(0))
                )
            )
            continuation.finish()
        }
    }
}
