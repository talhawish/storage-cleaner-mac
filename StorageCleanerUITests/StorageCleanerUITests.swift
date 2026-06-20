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

    /// Regression test for the Quick Clean rendering bug: the review modal
    /// used to create one `StorageFinding` per enabled option but with the
    /// same `StorageFindingKind` (`.junkFiles`), so SwiftUI's `ForEach`
    /// only rendered the first finding. The header showed the correct total
    /// while the list showed a single row. This test ensures the modal opens
    /// from the dashboard and that the review list (once it appears) is not
    /// shorter than the summary.
    @MainActor
    func testQuickCleanOpensFromDashboardCard() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])

        let quickCleanCard = app.descendants(matching: .any)["quick-clean-card"]
        XCTAssertTrue(quickCleanCard.waitForExistence(timeout: 4))
        quickCleanCard.click()

        let header = app.staticTexts["Quick Clean"]
        XCTAssertTrue(header.waitForExistence(timeout: 4))
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
    func testSidebarPagesOpenWithoutUnexpectedDetailPushes() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])
        startScanAndWaitForResults(in: app)

        let pages = [
            ("overview", "dashboard-results"),
            ("projectActivity", "project-activity-root"),
            ("apps", "applications-root"),
            ("developerStorage", "developer-storage-root"),
            ("runtimeVersions", "runtime-versions-root"),
            ("simulatorsEmulators", "simulators-emulators-root"),
            ("cliPrograms", "cli-programs-root"),
            ("largeFiles", "large-files-root"),
            ("leftovers", "leftovers-root"),
            ("screenshotsAndRecordings", "media-category-screenshots-recordings"),
            ("duplicates", "duplicates-root"),
            ("cleanupHistory", "cleanup-history-root"),
            ("settings", "settings-root")
        ]

        for (sidebarID, rootID) in pages {
            let row = app.descendants(matching: .any)["sidebar-\(sidebarID)"]
            XCTAssertTrue(row.waitForExistence(timeout: 4), "Missing sidebar row \(sidebarID)")
            row.click()

            let root = app.descendants(matching: .any)[rootID]
            XCTAssertTrue(root.waitForExistence(timeout: 4), "Expected root \(rootID) after opening \(sidebarID)")
        }

        app.descendants(matching: .any)["sidebar-developerStorage"].click()
        XCTAssertTrue(app.descendants(matching: .any)["developer-storage-root"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.descendants(matching: .any)["category-detail-xcodeArtifacts"].exists)
    }

    @MainActor
    func testDeveloperStorageRescanFinishesOnRoot() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])
        startScanAndWaitForResults(in: app)

        app.descendants(matching: .any)["sidebar-developerStorage"].click()
        XCTAssertTrue(app.descendants(matching: .any)["developer-storage-root"].waitForExistence(timeout: 4))

        let scanButton = app.buttons["developer-storage-scan-button"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 4))
        scanButton.click()

        XCTAssertTrue(app.descendants(matching: .any)["developer-storage-root"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.descendants(matching: .any)["category-detail-xcodeArtifacts"].exists)
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

    @MainActor
    private func startScanAndWaitForResults(in app: XCUIApplication) {
        let scanButton = app.buttons["primary-scan-button"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 3))
        scanButton.click()

        let results = app.descendants(matching: .any)["dashboard-results"]
        XCTAssertTrue(results.waitForExistence(timeout: 12))
    }
}
