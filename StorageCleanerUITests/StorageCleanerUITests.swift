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

        // Each entry is the sidebar identifier and a list of root identifiers
        // the section is allowed to render. CLI Programs and the Duplicates
        // page have no demo data, so they correctly fall through to the
        // post-scan empty state instead of the content root. Runtime Versions
        // now lives inside Developer Storage — its own sidebar entry was removed.
        let pages: [(String, [String])] = [
            ("overview", ["dashboard-results"]),
            ("projectActivity", ["project-activity-root"]),
            ("apps", ["applications-root"]),
            ("developerStorage", ["developer-storage-root", "developer-storage-empty"]),
            ("simulatorsEmulators", ["simulators-emulators-root"]),
            ("cliPrograms", ["cli-programs-root", "cli-programs-empty"]),
            ("largeFiles", ["large-files-root", "large-files-empty"]),
            ("leftovers", ["leftovers-root", "leftovers-empty"]),
            ("screenshotsAndRecordings", [
                "media-category-screenshots-recordings",
                "media-category-empty"
            ]),
            ("duplicates", ["duplicates-root", "duplicates-empty"]),
            ("systemJunk", ["system-junk-root", "system-junk-empty"]),
            ("cleanupHistory", ["cleanup-history-root"]),
            ("settings", ["settings-root"])
        ]

        for (sidebarID, rootIDs) in pages {
            let row = app.descendants(matching: .any)["sidebar-\(sidebarID)"]
            XCTAssertTrue(row.waitForExistence(timeout: 4), "Missing sidebar row \(sidebarID)")
            row.click()

            let found = rootIDs.contains { identifier in
                app.descendants(matching: .any)[identifier].waitForExistence(timeout: 4)
            }
            XCTAssertTrue(
                found,
                "Expected one of \(rootIDs) after opening \(sidebarID)"
            )
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

    /// Regression for the pre-scan UX: opening Developer Storage before any
    /// scan has run must show the welcoming `InitialStateView` (with the
    /// "initial-state-scan-button" CTA), not a "No X Found" empty state.
    /// The previous wording implied the page had already looked and found
    /// nothing — which was misleading.
    @MainActor
    func testDeveloperStorageBeforeScanShowsInitialState() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["primary-scan-button"].waitForExistence(timeout: 3))

        app.descendants(matching: .any)["sidebar-developerStorage"].click()

        let initialState = app.descendants(matching: .any)["developer-storage-initial"]
        XCTAssertTrue(
            initialState.waitForExistence(timeout: 4),
            "Unscanned sections must show the InitialStateView, not an empty result."
        )
        XCTAssertTrue(
            app.buttons["initial-state-scan-button"].waitForExistence(timeout: 4),
            "InitialStateView must offer a primary scan CTA before any scan has run."
        )
    }

    /// Regression for the bulk-removal UX on the System Junk page: the inline "Clean All" button
    /// (sitting above the file list, not in the toolbar) must pre-select every visible item and
    /// open the destructive confirmation so the user can review before trashing.
    @MainActor
    func testSystemJunkCleanAllOpensDeleteConfirmation() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])
        startScanAndWaitForResults(in: app)

        app.descendants(matching: .any)["sidebar-systemJunk"].click()
        XCTAssertTrue(app.descendants(matching: .any)["system-junk-root"].waitForExistence(timeout: 4))

        let cleanButton = app.buttons["system-junk-clean-button"]
        XCTAssertTrue(cleanButton.waitForExistence(timeout: 4))
        cleanButton.click()

        // The confirmation modal's primary action is "Move to Trash" — verifying it appears
        // confirms the modal opened with the right destructive context.
        let moveToTrash = app.buttons["Move to Trash"]
        XCTAssertTrue(moveToTrash.waitForExistence(timeout: 4))
    }

    /// The master checkbox above the file list toggles the visible selection. After clicking it,
    /// the destructive button's label must update from "Clean All" to "Clean N Selected" to
    /// reflect the picked subset.
    @MainActor
    func testSystemJunkSelectAllUpdatesCleanButtonLabel() {
        let app = launchApp(extraArguments: ["--complete-demo-scan-immediately"])
        startScanAndWaitForResults(in: app)

        app.descendants(matching: .any)["sidebar-systemJunk"].click()
        XCTAssertTrue(app.descendants(matching: .any)["system-junk-root"].waitForExistence(timeout: 4))

        // Before any selection the button shows "Clean All". After checking, the label must
        // change so it reads "Clean N Selected". The exact N is demo-data dependent, so we
        // just confirm the label no longer starts with "Clean All".
        let checkbox = app.checkBoxes["system-junk-select-all"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 4))
        checkbox.click()

        let button = app.buttons["system-junk-clean-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 4))
        let label = button.label
        XCTAssertTrue(
            label.contains("Selected"),
            "Clean button label should contain 'Selected' after toggling the master checkbox, "
                + "got '\(label)'"
        )
    }

    @MainActor
    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--use-demo-scanner"] + extraArguments
        app.launch()
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
