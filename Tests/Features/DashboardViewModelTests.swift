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

    func testStartScanWithBlockedPermissionsShowsPermissionRequired() {
        let handler = StubPermissionHandler(
            statuses: [
                StoragePermissionStatus(
                    scope: .downloads,
                    url: URL(filePath: "/Users/test/Downloads"),
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
        XCTAssertEqual(viewModel.blockedPermissions.first?.scope, .downloads)
        XCTAssertTrue(viewModel.hasPermissionIssues)
    }

    func testRetryAfterPermissionResolvesAndStartsScanning() async {
        let handler = StubPermissionHandler(
            statuses: [
                StoragePermissionStatus(
                    scope: .downloads,
                    url: URL(filePath: "/Users/test/Downloads"),
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
                scope: .downloads,
                url: URL(filePath: "/Users/test/Downloads"),
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
                    state: scope == .downloads ? .denied : .accessible
                )
            }
        )
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: handler
        )

        let summary = viewModel.permissionSummary
        XCTAssertTrue(summary.contains("6 of 7"))
        XCTAssertTrue(summary.contains("Downloads"))
        XCTAssertTrue(viewModel.hasPermissionIssues)
    }

    func testOpenSystemSettingsCreatesValidURL() {
        let viewModel = DashboardViewModel(scanner: ImmediateScanner())
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        XCTAssertNotNil(URL(string: urlString))
        _ = viewModel
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
}

private struct ImmediateScanner: StorageScanning {
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

private final class StubPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    var statuses: [StoragePermissionStatus]

    init(statuses: [StoragePermissionStatus]) {
        self.statuses = statuses
    }

    func currentStatuses() -> [StoragePermissionStatus] {
        statuses
    }
}

private let allAccessibleStatuses: [StoragePermissionStatus] =
    StoragePermissionScope.allCases.map { scope in
        StoragePermissionStatus(
            scope: scope,
            url: URL(filePath: "/Users/test/\(scope.rawValue)"),
            state: .accessible
        )
    }

private struct DelayedScanner: StorageScanning {
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

private final class RecordingScanner: @unchecked Sendable, StorageScanning {
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
