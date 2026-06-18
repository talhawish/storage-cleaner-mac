import XCTest
@testable import StorageCleaner

final class LiveStorageScannerTests: XCTestCase {
    func testLiveScannerEmitsPerScannerProgressAndCompletion() async {
        let scanner = LiveStorageScanner(
            scanners: [
                StubCategoryScanner(
                    kind: .screenshots,
                    result: CategoryScanResult(
                        finding: nil,
                        inspectedItemCount: 0,
                        message: "None"
                    )
                ),
                StubCategoryScanner(kind: .trash, result: trashResult)
            ]
        )
        var progressEvents: [[ScannerProgress]] = []
        var snapshot: ScanSnapshot?

        for await event in scanner.scanEvents() {
            switch event {
            case let .progress(_, _, _, progress):
                progressEvents.append(progress)
            case let .completed(completedSnapshot):
                snapshot = completedSnapshot
            }
        }

        XCTAssertFalse(progressEvents.isEmpty)
        XCTAssertEqual(progressEvents.first?.count, 2)
        XCTAssertEqual(snapshot?.findings.count, 1)
        XCTAssertEqual(snapshot?.findings.first?.kind, .trash)
    }

    func testConcurrentScanningViaTaskGroupCollectsAllResults() async {
        let expectation = expectation(description: "All scanners complete")
        let scanner = LiveStorageScanner(
            scanners: [
                StubCategoryScanner(kind: .screenshots, delay: .milliseconds(50), result: screenshotsResult),
                StubCategoryScanner(kind: .trash, delay: .milliseconds(30), result: trashResult),
                StubCategoryScanner(kind: .junkFiles, delay: .milliseconds(10), result: junkResult)
            ]
        )
        var snapshot: ScanSnapshot?

        for await event in scanner.scanEvents() {
            if case let .completed(result) = event {
                snapshot = result
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 2)
        let kinds = snapshot?.findings.map(\.kind) ?? []
        XCTAssertTrue(kinds.contains(.screenshots))
        XCTAssertTrue(kinds.contains(.trash))
        XCTAssertTrue(kinds.contains(.junkFiles))
        XCTAssertEqual(snapshot?.findings.count, 3)
        XCTAssertEqual(snapshot?.scannedItemCount, 3)
    }

    private var screenshotsResult: CategoryScanResult {
        CategoryScanResult(
            finding: StorageFinding(
                kind: .screenshots,
                domain: .screenshots,
                bytes: 100,
                itemCount: 1,
                safety: .review,
                examples: ["Screen shot 1.png"]
            ),
            inspectedItemCount: 1,
            message: "Found"
        )
    }

    private var trashResult: CategoryScanResult {
        CategoryScanResult(
            finding: StorageFinding(
                kind: .trash,
                domain: .trash,
                bytes: 42,
                itemCount: 1,
                safety: .review,
                examples: ["old.zip"]
            ),
            inspectedItemCount: 1,
            message: "Measured"
        )
    }

    private var junkResult: CategoryScanResult {
        CategoryScanResult(
            finding: StorageFinding(
                kind: .junkFiles,
                domain: .otherCaches,
                bytes: 77,
                itemCount: 1,
                safety: .safe,
                examples: ["tmp.log"]
            ),
            inspectedItemCount: 1,
            message: "Cleaned"
        )
    }
}

private struct StubCategoryScanner: StorageCategoryScanning {
    let kind: StorageFindingKind
    let delay: Duration
    let result: CategoryScanResult

    init(kind: StorageFindingKind, delay: Duration = .zero, result: CategoryScanResult? = nil) {
        self.kind = kind
        self.delay = delay
        self.result = result ?? CategoryScanResult(
            finding: nil,
            inspectedItemCount: 0,
            message: "None"
        )
    }

    var title: String {
        kind.title
    }

    func scan() async -> CategoryScanResult {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }
}
