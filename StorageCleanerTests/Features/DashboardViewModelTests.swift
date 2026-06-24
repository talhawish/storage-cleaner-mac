import XCTest
@testable import StorageCleaner

@MainActor
final class DashboardViewModelTests: XCTestCase {
    func testCompletedScanPublishesResults() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()

        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertEqual(viewModel.progress, 1)
        XCTAssertNotNil(viewModel.snapshot)
        XCTAssertGreaterThan(viewModel.scannedItemCount, 0)
    }

    func testCancelReturnsToIdle() {
        let viewModel = DashboardViewModel(
            scanner: DelayedScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()
        viewModel.cancelScan()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertEqual(viewModel.progress, 0)
        XCTAssertFalse(viewModel.isScanning)
    }

    func testStreamFinishingWithoutCompletionShowsFailedPhase() async {
        let viewModel = DashboardViewModel(
            scanner: EmptyStreamScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()

        for _ in 0..<20 {
            if case .failed = viewModel.phase { break }
            await Task.yield()
        }

        guard case let .failed(message) = viewModel.phase else {
            return XCTFail("Expected failed phase, got \(viewModel.phase)")
        }
        XCTAssertTrue(message.contains("stopped before it completed"))
        XCTAssertFalse(viewModel.isScanning)
    }

    func testStartScanWithBlockedPermissionsShowsPermissionRequired() {
        let handler = StubPermissionHandler(
            statuses: [
                StoragePermissionStatus(
                    scope: .home,
                    url: URL(filePath: "/Users/test"),
                    state: .denied
                )
            ]
        )
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: handler
        )

        viewModel.startScan()

        XCTAssertEqual(viewModel.phase, .permissionRequired)
        XCTAssertEqual(viewModel.blockedPermissions.count, 1)
        XCTAssertEqual(viewModel.blockedPermissions.first?.scope, .home)
        XCTAssertTrue(viewModel.hasPermissionIssues)
    }

    func testRetryAfterPermissionResolvesAndStartsScanning() async {
        let handler = StubPermissionHandler(
            statuses: [
                StoragePermissionStatus(
                    scope: .home,
                    url: URL(filePath: "/Users/test"),
                    state: .denied
                )
            ]
        )
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: handler
        )

        viewModel.startScan()
        XCTAssertEqual(viewModel.phase, .permissionRequired)

        handler.statuses = [
            StoragePermissionStatus(
                scope: .home,
                url: URL(filePath: "/Users/test"),
                state: .accessible
            )
        ]

        viewModel.retryAfterPermission()

        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertFalse(viewModel.hasPermissionIssues)
    }

    func testPermissionSummaryReflectsIssues() {
        let handler = StubPermissionHandler(
            statuses: StoragePermissionScope.allCases.map { scope in
                StoragePermissionStatus(
                    scope: scope,
                    url: URL(filePath: "/Users/test/\(scope.rawValue)"),
                    state: scope == .home ? .denied : .accessible
                )
            }
        )
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: handler
        )

        let summary = viewModel.permissionSummary
        XCTAssertTrue(summary.contains("Home Folder access required"))
        XCTAssertTrue(summary.contains("/Users/test/home"))
        XCTAssertTrue(viewModel.hasPermissionIssues)
    }

    func testFullDiskAccessSettingsLinkResolves() {
        let url = SystemSettingsPane.fullDiskAccess.url
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "x-apple.systempreferences")
    }

    func testTargetedScanPassesRequestedKindsToScanner() async {
        let scanner = RecordingScanner()
        let viewModel = DashboardViewModel(
            scanner: scanner,
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan(for: [.screenshots, .screenRecordings])

        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(scanner.requestedKinds, [.screenshots, .screenRecordings])
    }

    func testTargetedScanPreservesUnrelatedExistingFindings() async {
        let scanner = RecordingScanner()
        let viewModel = DashboardViewModel(
            scanner: scanner,
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        scanner.snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .screenRecordings,
                    domain: .media,
                    bytes: 20,
                    itemCount: 1,
                    safety: .review,
                    examples: [],
                    filePaths: []
                )
            ],
            scannedItemCount: 1,
            duration: .seconds(1)
        )
        viewModel.startScan(for: [.screenRecordings])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        let kinds = viewModel.snapshot?.findings.map(\.kind) ?? []
        XCTAssertTrue(kinds.contains(.screenshots))
        XCTAssertTrue(kinds.contains(.screenRecordings))
    }

    func testFullScanIsRecordedInHistory() async {
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            historyStore: store
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(store.recordedScans.count, 1)
        XCTAssertEqual(store.recordedScans.first?.findings.first?.kind, .largeVideos)
    }

    func testTargetedScanIsNotRecordedInHistory() async {
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: RecordingScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            historyStore: store
        )

        viewModel.startScan(for: [.screenshots])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }
        XCTAssertTrue(store.recordedScans.isEmpty)
    }

    /// Regression: scanning only Developer must leave Screenshots in "never scanned" mode.
    func testHasScannedReflectsLastScanKinds() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        XCTAssertFalse(viewModel.hasScanned([.xcodeArtifacts]))
        XCTAssertFalse(viewModel.hasScanned([.screenshots]))

        viewModel.startScan(for: [.xcodeArtifacts])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertTrue(viewModel.hasScanned([.xcodeArtifacts]))
        XCTAssertFalse(viewModel.hasScanned([.screenshots, .screenRecordings]))
    }

    /// After a full scan, every kind is considered "scanned."
    func testFullScanMarksAllKindsAsScanned() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertTrue(viewModel.hasScanned([.xcodeArtifacts]))
        XCTAssertTrue(viewModel.hasScanned([.screenshots, .screenRecordings]))
        XCTAssertTrue(viewModel.hasScanned([.cliApps]))
    }
    /// A follow-up targeted scan overwrites the "last scanned" marker.
    func testLastScanKindsIsReplacedByNewTargetedScan() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan(for: [.xcodeArtifacts])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }
        XCTAssertTrue(viewModel.hasScanned([.xcodeArtifacts]))

        viewModel.startScan(for: [.screenshots])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }
        XCTAssertTrue(viewModel.hasScanned([.screenshots]))
        XCTAssertFalse(viewModel.hasScanned([.xcodeArtifacts]))
    }

    func testDeleteRecordsCleanupAuditAndPrunesFindings() async {
        let fileA = URL(filePath: "/tmp/a.bin")
        let fileB = URL(filePath: "/tmp/b.bin")
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .largeFiles,
                    domain: .media,
                    bytes: 100,
                    itemCount: 2,
                    safety: .safe,
                    examples: [],
                    filePaths: [fileA, fileB]
                )
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )
        let store = SpyHistoryStore()
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: [fileA: 40]),
            historyStore: store
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([fileA])

        XCTAssertEqual(store.recordedCleanups.count, 1)
        XCTAssertEqual(
            store.recordedCleanups.first,
            [CleanupAuditEntry(kind: .largeFiles, bytesReclaimed: 40, itemCount: 1, samplePaths: [fileA])]
        )

        let finding = viewModel.snapshot?.findings.first
        XCTAssertEqual(finding?.filePaths, [fileB])
        XCTAssertEqual(finding?.bytes, 60)
        XCTAssertEqual(finding?.itemCount, 1)
    }

}

/// Duplicate-group delete/prune behavior. Split into its own class so each test type stays under
/// SwiftLint's `type_body_length` limit; the file-scoped stubs below are shared.
@MainActor
final class DashboardViewModelDuplicatePruneTests: XCTestCase {
    func testDeleteCollapsesDuplicateGroupWhenOnlyOneCopyRemains() async {
        let keep = URL(filePath: "/tmp/keep.png")
        let dupe = URL(filePath: "/tmp/dupe.png")
        let group = DuplicateGroup(
            contentHash: "hash",
            files: [
                DuplicateFile(url: keep, bytes: 50, modifiedAt: nil),
                DuplicateFile(url: dupe, bytes: 50, modifiedAt: nil)
            ],
            keepURL: keep
        )
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .duplicatePhotos,
                    domain: .photos,
                    bytes: 50,
                    itemCount: 1,
                    safety: .review,
                    examples: [],
                    filePaths: [dupe],
                    duplicateGroups: [group]
                )
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: [dupe: 50])
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([dupe])

        // Removing the only duplicate leaves a single copy, so the finding (and its group) drops.
        XCTAssertTrue(viewModel.snapshot?.findings.isEmpty ?? false)
    }

    func testDeleteReElectsKeepWhenKeptCopyIsRemoved() async {
        let keep = URL(filePath: "/tmp/keep.png")
        let dupeA = URL(filePath: "/tmp/dupeA.png")
        let dupeB = URL(filePath: "/tmp/dupeB.png")
        let group = DuplicateGroup(
            contentHash: "hash",
            files: [keep, dupeA, dupeB].map { DuplicateFile(url: $0, bytes: 50, modifiedAt: nil) },
            keepURL: keep
        )
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .duplicatePhotos,
                    domain: .photos,
                    bytes: 100,
                    itemCount: 2,
                    safety: .review,
                    examples: [],
                    filePaths: [dupeA, dupeB],
                    duplicateGroups: [group]
                )
            ],
            scannedItemCount: 3,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: [keep: 50])
        )

        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        _ = await viewModel.deleteFiles([keep])

        let prunedGroup = viewModel.snapshot?.findings.first?.duplicateGroups.first
        XCTAssertEqual(prunedGroup?.files.count, 2)
        XCTAssertNotNil(prunedGroup?.keepURL)
        XCTAssertNotEqual(prunedGroup?.keepURL, keep)
        XCTAssertTrue(prunedGroup.map { $0.files.map(\.url).contains($0.keepURL) } ?? false)
    }

    // MARK: - Cancel scan preserves previous results

    func testCancelPreservesPreviousSnapshot() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )
        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results { await Task.yield() }
        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertNotNil(viewModel.snapshot)

        // Cancel a targeted scan that started after a full scan completed.
        viewModel.startScan(for: [.screenshots])
        viewModel.cancelScan()

        // Must restore .results from the prior snapshot, not force .idle.
        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertNotNil(viewModel.snapshot)
    }

    func testCancelWithNoSnapshotReturnsToIdle() {
        let viewModel = DashboardViewModel(
            scanner: DelayedScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )
        viewModel.startScan(for: [.largeVideos])
        viewModel.cancelScan()
        XCTAssertEqual(viewModel.phase, .idle)
    }

    // MARK: - Scanner stream ending without .completed

    func testScannerStreamEndWithoutCompletedFails() async {
        let viewModel = DashboardViewModel(
            scanner: EmptyStreamScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )
        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase == .scanning { await Task.yield() }
        guard case let .failed(message) = viewModel.phase else {
            return XCTFail("Expected failed phase, got \(viewModel.phase)")
        }
        XCTAssertTrue(message.contains("stopped before it completed"))
    }
}
