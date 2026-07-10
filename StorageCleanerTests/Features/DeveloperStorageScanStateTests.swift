import XCTest
@testable import StorageCleaner

@MainActor
final class DeveloperStorageScanStateTests: XCTestCase {
    /// Regression: a result from an overlapping developer category must not make the
    /// Developer Storage screen look fully scanned. It should retain its initial scan action.
    func testPartialDeveloperScanDoesNotMarkDeveloperStorageAsScanned() async {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan(for: [.xcodeArtifacts, .iosDeviceSupport])
        for _ in 0..<20 where viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.hasScanned(DeveloperDomains.kinds))

        viewModel.startScan(for: DeveloperDomains.kinds)
        for _ in 0..<20 where !viewModel.hasScanned(DeveloperDomains.kinds) {
            await Task.yield()
        }

        XCTAssertTrue(viewModel.hasScanned(DeveloperDomains.kinds))
    }
}
