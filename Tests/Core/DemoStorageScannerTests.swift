import XCTest
@testable import StorageCleaner

final class DemoStorageScannerTests: XCTestCase {
    func testScannerReportsMonotonicProgressAndResults() async {
        let scanner = DemoStorageScanner(stepDelay: .zero)
        var progressValues: [Double] = []
        var completedSnapshot: ScanSnapshot?

        for await event in scanner.scanEvents() {
            switch event {
            case let .progress(fraction, _, _, scannerProgress):
                progressValues.append(fraction)
                XCTAssertFalse(scannerProgress.isEmpty)
            case let .completed(snapshot):
                completedSnapshot = snapshot
            }
        }

        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues, progressValues.sorted())
        XCTAssertEqual(progressValues.last, 1)
        XCTAssertEqual(completedSnapshot?.findings.count, StorageFindingKind.allCases.count)
        XCTAssertGreaterThan(completedSnapshot?.reclaimableBytes ?? 0, 0)
    }

    func testScannerReportsMediaPackagesBrowserCachesAndTrash() async {
        let scanner = DemoStorageScanner(stepDelay: .zero)
        var completedSnapshot: ScanSnapshot?

        for await event in scanner.scanEvents() {
            if case let .completed(snapshot) = event {
                completedSnapshot = snapshot
            }
        }

        let kinds = completedSnapshot?.findings.map(\.kind) ?? []
        XCTAssertTrue(kinds.contains(.largeVideos))
        XCTAssertTrue(kinds.contains(.screenRecordings))
        XCTAssertTrue(kinds.contains(.largePhotos))
        XCTAssertTrue(kinds.contains(.duplicatePhotos))
        XCTAssertTrue(kinds.contains(.duplicateVideos))
        XCTAssertTrue(kinds.contains(.screenshots))
        XCTAssertTrue(kinds.contains(.androidPackages))
        XCTAssertTrue(kinds.contains(.androidStudioArtifacts))
        XCTAssertTrue(kinds.contains(.flutterArtifacts))
        XCTAssertTrue(kinds.contains(.browserCaches))
        XCTAssertTrue(kinds.contains(.packageArtifacts))
        XCTAssertTrue(kinds.contains(.junkFiles))
        XCTAssertTrue(kinds.contains(.cliApps))
        XCTAssertTrue(kinds.contains(.trash))
    }

    func testCLIAppFixtureIncludedInDemoScan() async {
        let scanner = DemoStorageScanner(stepDelay: .zero)
        var snapshot: ScanSnapshot?

        for await event in scanner.scanEvents() {
            if case let .completed(snap) = event {
                snapshot = snap
            }
        }

        let cliFinding = snapshot?.findings.first { $0.kind == .cliApps }
        XCTAssertNotNil(cliFinding)
        XCTAssertEqual(cliFinding?.domain, .cliTooling)
        XCTAssertEqual(cliFinding?.bytes, 9_180_000_000)
        XCTAssertEqual(cliFinding?.itemCount, 247)
        XCTAssertTrue(cliFinding?.examples.contains("Homebrew Cellar & Caskroom") ?? false)
    }

    func testSnapshotSumsReclaimableBytes() {
        let snapshot = ScanSnapshot(
            findings: [
                StorageFinding(
                    kind: .dockerArtifacts,
                    domain: .containers,
                    bytes: 10,
                    itemCount: 1,
                    safety: .review,
                    examples: []
                ),
                StorageFinding(
                    kind: .packageArtifacts,
                    domain: .otherCaches,
                    bytes: 25,
                    itemCount: 2,
                    safety: .safe,
                    examples: []
                )
            ],
            scannedItemCount: 3,
            duration: .seconds(1)
        )

        XCTAssertEqual(snapshot.reclaimableBytes, 35)
    }
}
