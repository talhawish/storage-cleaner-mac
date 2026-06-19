import XCTest

final class StorageCleanerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrimaryScanFlowShowsResults() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])

        let scanButton = app.buttons["primary-scan-button"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 3))
        scanButton.click()

        let summary = app.staticTexts["Potentially reclaimable"]
        XCTAssertTrue(summary.waitForExistence(timeout: 12))
    }

    @MainActor
    func testScanCanBeCancelled() {
        let app = launchApp()

        startScan(in: app)

        let cancelButton = app.buttons["cancel-scan-button"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.click()

        XCTAssertTrue(app.buttons["primary-scan-button"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--use-demo-scanner"] + extraArguments
        app.launch()
        app.activate()
        return app
    }

    @MainActor
    private func startScan(in app: XCUIApplication) {
        let scanButton = app.buttons["primary-scan-button"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 3))
        scanButton.click()

        let progressTitle = app.staticTexts["scan-progress-title"]
        if !progressTitle.waitForExistence(timeout: 3), scanButton.exists {
            scanButton.click()
        }

        XCTAssertTrue(progressTitle.waitForExistence(timeout: 3))
    }
}
