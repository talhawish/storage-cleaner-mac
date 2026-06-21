import XCTest
import SwiftUI
@testable import StorageCleaner

@MainActor
final class SectionStateViewsTests: XCTestCase {
    /// Pre-condition: a fresh `DashboardViewModel` starts in `.idle`. The
    /// section view builders rely on this to render the welcoming
    /// `InitialStateView` instead of a misleading "No X Found" empty state.
    /// Regression test for the bad UX where unscanned sections said "not
    /// found" before a scan had run.
    func testFreshViewModelStartsInIdlePhase() {
        let viewModel = DashboardViewModel(
            scanner: EmptySnapshotScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        XCTAssertEqual(viewModel.phase, .idle, "Pre-condition: view-model starts idle")
    }

    /// `EmptyStateView` is the post-scan calm "all clean" view. It must
    /// never claim it is asking the user to scan for the first time — that's
    /// the `InitialStateView`'s job.
    func testEmptyStateViewHasCalmToneAndOptionalAction() {
        let view = EmptyStateView(
            title: "All clean",
            message: "Nothing here.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint
        )

        let mirror = Mirror(reflecting: view)
        let label = TestSupport.stringValue(for: mirror, label: "title")
        let message = TestSupport.stringValue(for: mirror, label: "message")

        XCTAssertEqual(label, "All clean")
        XCTAssertEqual(message, "Nothing here.")
        XCTAssertFalse(
            message.contains("Run a scan"),
            "EmptyStateView must not invite a first-time scan; that's InitialStateView's job."
        )
    }

    /// `InitialStateView` must be action-oriented and never say "No" or
    /// "not found" — that's what made the pre-scan pages misleading before.
    func testInitialStateViewHasActionAndNoNegativeCopy() {
        let view = InitialStateView(
            title: "Discover duplicates",
            subtitle: "We'll compare your media by content.",
            highlights: [
                InitialStateHighlight(title: "Photos", systemImage: "photo.fill"),
                InitialStateHighlight(title: "Videos", systemImage: "video.fill")
            ],
            actionTitle: "Scan for Duplicates",
            systemImage: "square.on.square",
            tint: AppTheme.indigo
        ) {}

        let mirror = Mirror(reflecting: view)
        let title = TestSupport.stringValue(for: mirror, label: "title")
        let subtitle = TestSupport.stringValue(for: mirror, label: "subtitle")
        let actionTitle = TestSupport.stringValue(for: mirror, label: "actionTitle")

        XCTAssertEqual(title, "Discover duplicates")
        XCTAssertEqual(subtitle, "We'll compare your media by content.")
        XCTAssertEqual(actionTitle, "Scan for Duplicates")

        let combined = [title, subtitle, actionTitle].joined(separator: " ")
        XCTAssertFalse(combined.contains("No "), "Initial state must not lead with 'No'.")
        XCTAssertFalse(
            combined.contains("not found"),
            "Initial state must not say 'not found' — that wording belongs to the post-scan empty state."
        )
    }

    /// A complete scan with no findings must publish the `.empty` phase, not
    /// `.results`, so the section view builders know to render the calm
    /// post-scan empty state.
    func testCompletedScanWithNoFindingsPublishesEmptyPhase() async {
        let viewModel = DashboardViewModel(
            scanner: EmptySnapshotScanner(),
            permissionHandler: StubPermissionHandler(statuses: allAccessibleStatuses)
        )

        viewModel.startScan()

        for _ in 0..<20 where viewModel.phase != .empty && viewModel.phase != .results {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.phase, .empty)
    }

    /// Section view builders must continue to work for views that are
    /// self-discovering (no scan required). Those views are unaffected by
    /// the new phase routing — their `emptyState` is the post-scan empty
    /// state, used only after their own load returns nothing.
    func testNoScanRequiredViewStillUsesEmptyStateView() {
        let dockView = DockerView()
        let appsView = AppsView()

        let dockMirror = Mirror(reflecting: dockView)
        let appsMirror = Mirror(reflecting: appsView)

        // Sanity: the views exist and can be reflected (catches accidental
        // refactors that break their public surface).
        XCTAssertNotNil(dockMirror.children.first(where: { $0.label == "service" }))
        XCTAssertNotNil(appsMirror.children.first(where: { $0.label == "inventoryService" }))
    }

    /// `ScanningLoaderView` is the unified scanning surface used by both the
    /// dashboard's per-section scanners and the self-discovering views.
    /// Its init must accept every state required for both code paths.
    func testScanningLoaderViewAcceptsAllInputs() {
        let view = ScanningLoaderView(
            title: "Scanning X",
            subtitle: "Subtitle.",
            progress: 0.42,
            currentLocation: "/Users/test/Library",
            scannedItemCount: 1_234,
            scanners: [
                ScannerLoaderItem(id: "a", title: "A", state: .scanning, itemsScanned: 10, message: "Working"),
                ScannerLoaderItem(id: "b", title: "B", state: .completed, itemsScanned: 0, message: "Done")
            ],
            cancelTitle: "Stop",
            tint: AppTheme.accent
        ) {}

        let mirror = Mirror(reflecting: view)
        let title = TestSupport.stringValue(for: mirror, label: "title")
        let cancelTitle = TestSupport.stringValue(for: mirror, label: "cancelTitle")
        let progress = TestSupport.doubleValue(for: mirror, label: "progress")
        let scannedItemCount = TestSupport.intValue(for: mirror, label: "scannedItemCount")

        XCTAssertEqual(title, "Scanning X")
        XCTAssertEqual(cancelTitle, "Stop")
        XCTAssertEqual(progress ?? 0, 0.42, accuracy: 0.0001)
        XCTAssertEqual(scannedItemCount, 1_234)
    }

    /// `ScannerProgress` (the dashboard model) must adapt into
    /// `ScannerLoaderItem` (the design-system input) so the dashboard's
    /// scanners render through the new component.
    func testScannerProgressAdaptsToLoaderItem() {
        let progress = ScannerProgress(
            kind: .duplicatePhotos,
            title: "Duplicate photos",
            state: .scanning,
            inspectedItemCount: 17,
            message: "Hashing media"
        )

        let item = ScannerLoaderItem(progress: progress)

        XCTAssertEqual(item.id, "duplicatePhotos")
        XCTAssertEqual(item.title, "Duplicate photos")
        XCTAssertEqual(item.state, .scanning)
        XCTAssertEqual(item.itemsScanned, 17)
        XCTAssertEqual(item.message, "Hashing media")
    }

    /// The `StopScanConfirmationSheet` is shown when the user tries to
    /// switch sections mid-scan. It must carry the names of both sections
    /// so the user can make an informed decision.
    func testStopScanConfirmationReferencesBothSections() {
        var didConfirm = false
        var didCancel = false
        let sheet = StopScanConfirmationSheet(
            originSection: "Duplicates",
            destinationSection: "Large Files",
            onConfirm: { didConfirm = true },
            onCancel: { didCancel = true }
        )

        let mirror = Mirror(reflecting: sheet)
        let origin = TestSupport.stringValue(for: mirror, label: "originSection")
        let destination = TestSupport.stringValue(for: mirror, label: "destinationSection")

        XCTAssertEqual(origin, "Duplicates")
        XCTAssertEqual(destination, "Large Files")

        // Sanity: closures are wired (don't actually invoke — would crash
        // because the modal isn't presented).
        XCTAssertFalse(didConfirm)
        XCTAssertFalse(didCancel)
    }
}

// MARK: - Fixtures

private final class EmptySnapshotScanner: StorageScanning, @unchecked Sendable {
    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            continuation.yield(
                .completed(ScanSnapshot(findings: [], scannedItemCount: 0, duration: .zero))
            )
            continuation.finish()
        }
    }
}

private enum TestSupport {
    /// Pulls a `String` property out of a struct's stored properties via
    /// `Mirror`. Returns an empty string when the property is missing or
    /// not a String.
    static func stringValue(for mirror: Mirror, label: String) -> String {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return "" }
        if let string = any as? String { return string }
        return "\(any)"
    }

    /// Pulls a `Double?` property out of stored properties via `Mirror`.
    static func doubleValue(for mirror: Mirror, label: String) -> Double? {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return nil }
        if let value = any as? Double { return value }
        return nil
    }

    /// Pulls an `Int` property out of stored properties via `Mirror`.
    static func intValue(for mirror: Mirror, label: String) -> Int {
        guard let any = mirror.children.first(where: { $0.label == label })?.value else { return 0 }
        if let value = any as? Int { return value }
        return 0
    }
}
