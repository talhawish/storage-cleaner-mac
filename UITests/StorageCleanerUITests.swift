import XCTest

final class StorageCleanerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryScanFlowShowsResults() {
        let app = launchApp()

        let scanButton = app.buttons["primary-scan-button"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 3))
        scanButton.click()

        XCTAssertTrue(app.staticTexts["scan-progress-title"].waitForExistence(timeout: 3))
        let reclaimableSummary = NSPredicate(
            format: "label CONTAINS %@",
            "potentially reclaimable"
        )
        let summary = app.buttons.matching(reclaimableSummary).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 12))
    }

    @MainActor
    func testScanCanBeCancelled() {
        let app = launchApp()

        app.buttons["primary-scan-button"].click()

        let cancelButton = app.buttons["cancel-scan-button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.click()

        XCTAssertTrue(app.buttons["primary-scan-button"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--use-demo-scanner"]
        app.launch()
        return app
    }
}
