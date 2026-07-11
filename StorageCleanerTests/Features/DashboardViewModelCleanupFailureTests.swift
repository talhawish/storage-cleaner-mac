import Foundation
import XCTest
@testable import StorageCleaner

/// Covers the app-wide cleanup-failure prompt: every delete path must raise
/// `cleanupFailure` when items are left behind (unless the caller opts out
/// because it surfaces the result itself) and retry must route the failed
/// items back through the operation that produced them.
@MainActor
final class DashboardViewModelCleanupFailureTests: XCTestCase {
    private let removed = URL(fileURLWithPath: "/Users/test/Library/Caches/GoodApp", isDirectory: true)
    private let denied = URL(fileURLWithPath: "/Users/test/Library/Caches/LockedApp", isDirectory: true)

    func testPartialFailureRaisesCleanupFailurePrompt() async {
        let viewModel = makeViewModel(
            cleanupService: FailingCleanupService(
                deletedBytesByURL: [removed: 40],
                failingURLs: [denied]
            )
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.deleteFiles([removed, denied])

        let prompt = viewModel.cleanupFailure
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.failedURLs, [denied])
        XCTAssertEqual(prompt?.route, .trash)
        XCTAssertTrue(prompt?.feedback.title.contains("1 item") ?? false)
    }

    func testAllFailedCleanupStillRaisesPrompt() async {
        let viewModel = makeViewModel(
            cleanupService: FailingCleanupService(deletedBytesByURL: [:], failingURLs: [removed, denied])
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.deleteFiles([removed, denied])

        XCTAssertEqual(viewModel.cleanupFailure?.failedURLs.count, 2)
    }

    func testSuccessfulCleanupLeavesNoPrompt() async {
        let viewModel = makeViewModel(
            cleanupService: StubCleanupService(reclaimedBytesByURL: [removed: 40])
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.deleteFiles([removed])

        XCTAssertNil(viewModel.cleanupFailure)
    }

    func testSurfacingCanBeSuppressedForFeatureLocalFlows() async {
        let viewModel = makeViewModel(
            cleanupService: FailingCleanupService(deletedBytesByURL: [:], failingURLs: [denied])
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.deleteFiles([denied], surfacingFailure: false)

        XCTAssertNil(viewModel.cleanupFailure)
        XCTAssertEqual(viewModel.lastCleanupResult?.failedCount, 1)
    }

    func testRetryRoutesTrashFailuresBackThroughDeleteFiles() async {
        let cleanupService = CountingCleanupService()
        let viewModel = makeViewModel(cleanupService: cleanupService)
        await loadSnapshot(in: viewModel)
        let prompt = CleanupFailurePrompt(
            feedback: .failed(result: CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [(denied, CleanupError.fileNotFound(denied))],
                totalBytesReclaimed: 0
            )),
            failedURLs: [denied],
            route: .trash
        )

        await viewModel.retryCleanup(prompt)

        XCTAssertEqual(cleanupService.deleteRequests, [[denied]])
    }

    func testCLIRemovalFailureRaisesPromptWithCLIRoute() async {
        let viewModel = makeViewModel(
            finding: StorageFinding(
                kind: .cliApps,
                domain: .cliTooling,
                bytes: 100,
                itemCount: 1,
                safety: .review,
                examples: [],
                filePaths: [denied]
            ),
            cliRemovalService: failingCLIRemovalService()
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.removeCLIPrograms([denied])

        XCTAssertEqual(viewModel.cleanupFailure?.route, .cliRemoval)
        XCTAssertEqual(viewModel.cleanupFailure?.failedURLs, [denied])
    }

    // MARK: - Helpers

    private func makeViewModel(
        finding: StorageFinding? = nil,
        cleanupService: CleanupService = StubCleanupService(reclaimedBytesByURL: [:]),
        cliRemovalService: CLIRemovalService? = nil
    ) -> DashboardViewModel {
        let defaultFinding = StorageFinding(
            kind: .orphanedAppCaches,
            domain: .systemJunk,
            bytes: 100,
            itemCount: 2,
            safety: .safe,
            examples: [],
            filePaths: [removed, denied],
            pathBytes: [removed: 40, denied: 60]
        )
        return DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: ScanSnapshot(
                findings: [finding ?? defaultFinding],
                scannedItemCount: 2,
                duration: .seconds(1)
            )),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: cleanupService,
            cliRemovalService: cliRemovalService ?? .live
        )
    }

    private func failingCLIRemovalService() -> CLIRemovalService {
        CLIRemovalService(
            locateBrew: { nil },
            runCommand: { _, _ in .init(exitCode: 1, output: "permission denied") },
            measure: { _ in 0 },
            trashItem: { _ in throw CocoaError(.fileWriteNoPermission) },
            homebrewLinkDirectories: { [] },
            symlinks: { _ in [] },
            isDangling: { _ in false },
            removeSymlink: { _ in },
            isExecutable: { _ in false },
            userBinDirectories: { [] }
        )
    }

    private func loadSnapshot(in viewModel: DashboardViewModel) async {
        viewModel.startScan()
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }
    }
}

private struct FailingCleanupService: CleanupService {
    let deletedBytesByURL: [URL: Int64]
    let failingURLs: [URL]

    func delete(urls: [URL]) async -> CleanupResult {
        let failingSet = Set(failingURLs)
        let deletedItems = urls.compactMap { url -> DeletedItem? in
            guard !failingSet.contains(url) else { return nil }
            return DeletedItem(originalURL: url, bytesReclaimed: deletedBytesByURL[url] ?? 0)
        }
        return CleanupResult(
            deletedURLs: deletedItems.map(\.originalURL),
            deletedItems: deletedItems,
            failedURLs: urls.filter { failingSet.contains($0) }.map {
                ($0, CleanupError.deletionFailed($0, CocoaError(.fileWriteNoPermission)))
            },
            totalBytesReclaimed: deletedItems.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        )
    }
}

private final class CountingCleanupService: @unchecked Sendable, CleanupService {
    private let lock = NSLock()
    private var requests: [[URL]] = []

    var deleteRequests: [[URL]] {
        lock.withLock { requests }
    }

    func delete(urls: [URL]) async -> CleanupResult {
        lock.withLock { requests.append(urls) }
        let items = urls.map { DeletedItem(originalURL: $0, bytesReclaimed: 10) }
        return CleanupResult(
            deletedURLs: urls,
            deletedItems: items,
            failedURLs: [],
            totalBytesReclaimed: Int64(items.count * 10)
        )
    }
}
