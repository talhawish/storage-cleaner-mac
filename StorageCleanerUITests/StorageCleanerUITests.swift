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

        let results = app.descendants(matching: .any)["dashboard-results"]
        XCTAssertTrue(results.waitForExistence(timeout: 12))
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
    func testSettingsShowsLargeFileThresholdPicker() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])

        let settingsRow = app.descendants(matching: .any)["sidebar-settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 3))
        settingsRow.click()

        let thresholdPicker = app.descendants(matching: .any)["large-file-threshold-picker"]
        XCTAssertTrue(thresholdPicker.waitForExistence(timeout: 3))

        let defaultThreshold = app.descendants(matching: .any)["large-file-threshold-100"]
        XCTAssertTrue(defaultThreshold.waitForExistence(timeout: 3))
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
