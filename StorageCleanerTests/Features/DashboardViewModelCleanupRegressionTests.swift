import Foundation
import XCTest
@testable import StorageCleaner

@MainActor
final class DashboardViewModelCleanupRegressionTests: XCTestCase {
    func testCLIProgramRemovalPrunesSnapshotPathsAndCounts() async {
        let removed = URL(fileURLWithPath: "/Users/test/.local/share/tool-a", isDirectory: true)
        let kept = URL(fileURLWithPath: "/Users/test/.local/share/tool-b", isDirectory: true)
        let viewModel = makeViewModel(
            finding: StorageFinding(
                kind: .cliApps,
                domain: .cliTooling,
                bytes: 100,
                itemCount: 2,
                safety: .review,
                examples: [],
                filePaths: [removed, kept],
                pathBytes: [removed: 40, kept: 60]
            ),
            cliSizes: [removed: 40]
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.removeCLIPrograms([removed])

        let finding = viewModel.snapshot?.findings.first
        XCTAssertEqual(finding?.filePaths, [kept])
        XCTAssertEqual(finding?.itemCount, 1)
        XCTAssertEqual(finding?.bytes, 60)
        XCTAssertEqual(finding?.pathBytes, [kept: 60])
    }

    func testRuntimeRemovalPrunesSnapshotEvenWhenMeasuredBytesAreZero() async {
        let removed = URL(fileURLWithPath: "/Users/test/.pyenv/versions/3.10.0", isDirectory: true)
        let kept = URL(fileURLWithPath: "/Users/test/.pyenv/versions/3.11.0", isDirectory: true)
        let store = SpyHistoryStore()
        let viewModel = makeViewModel(
            finding: StorageFinding(
                kind: .runtimeVersions,
                domain: .cliTooling,
                bytes: 100,
                itemCount: 2,
                safety: .review,
                examples: [],
                filePaths: [removed, kept]
            ),
            cliSizes: [removed: 0],
            historyStore: store
        )
        await loadSnapshot(in: viewModel)

        let result = await viewModel.removeRuntimeVersions([removed])

        XCTAssertEqual(result.totalBytesReclaimed, 0)
        XCTAssertEqual(viewModel.snapshot?.findings.first?.filePaths, [kept])
        XCTAssertEqual(viewModel.snapshot?.findings.first?.itemCount, 1)
        XCTAssertEqual(store.recordedCleanups.count, 1)
        XCTAssertEqual(store.recordedCleanups.first?.first?.kind, .runtimeVersions)
        XCTAssertEqual(store.recordedCleanups.first?.first?.bytesReclaimed, 0)
    }

    func testDeletePrunesPathWhenDeletedURLHasTrailingSlash() async {
        let scanned = URL(fileURLWithPath: "/tmp/cache", isDirectory: true)
        let deleted = URL(fileURLWithPath: "/tmp/cache/", isDirectory: true)
        let kept = URL(fileURLWithPath: "/tmp/other-cache", isDirectory: true)
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .browserCaches,
                    domain: .otherCaches,
                    bytes: 100,
                    itemCount: 2,
                    safety: .safe,
                    examples: [],
                    filePaths: [scanned, kept]
                )
            ],
            scannedItemCount: 2,
            duration: .seconds(1)
        )
        let viewModel = DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: snapshot),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cleanupService: StubCleanupService(reclaimedBytesByURL: [deleted: 40])
        )
        await loadSnapshot(in: viewModel)

        _ = await viewModel.deleteFiles([deleted])

        XCTAssertEqual(viewModel.snapshot?.findings.first?.filePaths, [kept])
        XCTAssertEqual(viewModel.snapshot?.findings.first?.itemCount, 1)
    }

    func testEmulatorCleanupReconcilesPathBackedDashboardFindingsAndHistory() async {
        let pack = URL(fileURLWithPath: "/Users/test/Library/Developer/Xcode/iOS DeviceSupport/26.0")
        let store = SpyHistoryStore()
        let viewModel = makeViewModel(
            finding: StorageFinding(
                kind: .iosDeviceSupport,
                domain: .appleDevelopment,
                bytes: 5_000,
                itemCount: 1,
                safety: .review,
                examples: [],
                filePaths: [pack]
            ),
            historyStore: store
        )
        await loadSnapshot(in: viewModel)
        let image = EmulatorImage(
            id: pack.path,
            platform: .iosDeviceSupport,
            title: "iOS 26.0",
            versionLabel: "26.0",
            key: VersionKey.parse("26.0"),
            bytes: 5_000,
            detail: "Build 23A",
            removal: .trashDirectory(pack),
            isRemovable: true,
            lastUsed: nil
        )

        await viewModel.reconcileEmulatorCleanup(
            EmulatorCleanupResult(removedIDs: [image.id], totalBytesReclaimed: 5_000, failures: []),
            removedImages: [image]
        )

        XCTAssertTrue(viewModel.snapshot?.findings.isEmpty ?? false)
        XCTAssertEqual(store.recordedCleanups.first?.first?.kind, .iosDeviceSupport)
        XCTAssertEqual(store.recordedCleanups.first?.first?.bytesReclaimed, 5_000)
        XCTAssertEqual(store.recordedCleanups.first?.first?.samplePaths, [pack])
    }

    private func makeViewModel(
        finding: StorageFinding,
        cliSizes: [URL: Int64] = [:],
        historyStore: SpyHistoryStore? = nil
    ) -> DashboardViewModel {
        DashboardViewModel(
            scanner: FixedSnapshotScanner(snapshot: ScanSnapshot(
                findings: [finding],
                scannedItemCount: finding.itemCount,
                duration: .seconds(1)
            )),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses),
            cliRemovalService: cliRemovalService(sizes: cliSizes),
            historyStore: historyStore
        )
    }

    private func cliRemovalService(sizes: [URL: Int64]) -> CLIRemovalService {
        CLIRemovalService(
            locateBrew: { nil },
            runCommand: { _, _ in .init(exitCode: 0, output: "") },
            measure: { sizes[$0] ?? 0 },
            trashItem: { _ in },
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
