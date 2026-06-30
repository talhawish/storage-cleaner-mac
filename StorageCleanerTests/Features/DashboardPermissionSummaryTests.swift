import XCTest
@testable import StorageCleaner

final class DashboardPermissionSummaryTests: XCTestCase {
    @MainActor
    func testMissingChildFolderDoesNotOverrideAccessibleHomeSummary() {
        let viewModel = DashboardViewModel(
            scanner: ImmediateScanner(),
            permissionHandler: StubPermissionHandler(
                statuses: [
                    StoragePermissionStatus(
                        scope: .home,
                        url: URL(filePath: "/Users/test"),
                        state: .accessible
                    ),
                    StoragePermissionStatus(
                        scope: .desktop,
                        url: URL(filePath: "/Users/test/Desktop"),
                        state: .missing
                    )
                ]
            )
        )

        XCTAssertEqual(viewModel.permissionSummary, "Home Folder access ready")
        XCTAssertFalse(viewModel.hasPermissionIssues)
    }
}
