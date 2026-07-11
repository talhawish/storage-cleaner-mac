import Foundation
import XCTest
@testable import StorageCleaner

/// Verifies the scanner window: `LiveStorageScanner` must never run more than
/// `maxConcurrentScanners` category scanners at once — each one performs
/// blocking filesystem enumeration, and unbounded parallelism thrashes the
/// disk and monopolizes the cooperative thread pool.
final class LiveStorageScannerConcurrencyTests: XCTestCase {
    private actor ConcurrencyMeter {
        private var active = 0
        private(set) var highWaterMark = 0

        func enter() {
            active += 1
            highWaterMark = max(highWaterMark, active)
        }

        func exit() {
            active -= 1
        }
    }

    private struct MeteredScanner: StorageCategoryScanning {
        let kind: StorageFindingKind
        let meter: ConcurrencyMeter

        var title: String { kind.title }

        func scan() async -> CategoryScanResult {
            await meter.enter()
            try? await Task.sleep(for: .milliseconds(20))
            await meter.exit()
            return CategoryScanResult(finding: nil, inspectedItemCount: 1, message: "None")
        }
    }

    func testConcurrentScannerCountNeverExceedsWindow() async {
        let meter = ConcurrencyMeter()
        let scanners = StorageFindingKind.allCases.map { kind in
            MeteredScanner(kind: kind, meter: meter)
        }
        let scanner = LiveStorageScanner(scanners: scanners)

        for await event in scanner.scanEvents() {
            if case .completed = event { break }
        }

        let highWaterMark = await meter.highWaterMark
        XCTAssertLessThanOrEqual(highWaterMark, LiveStorageScanner.maxConcurrentScanners)
        XCTAssertGreaterThan(highWaterMark, 1, "scanners should still run in parallel")
    }

    /// Every scanner must still run and report, even those beyond the initial
    /// window — the window launches replacements as scanners finish.
    func testAllScannersCompleteThroughTheWindow() async {
        let meter = ConcurrencyMeter()
        let scanners = StorageFindingKind.allCases.map { kind in
            MeteredScanner(kind: kind, meter: meter)
        }
        let scanner = LiveStorageScanner(scanners: scanners)

        var completedSnapshot: ScanSnapshot?
        var lastProgress: [ScannerProgress] = []
        for await event in scanner.scanEvents() {
            switch event {
            case let .progress(_, _, _, scannerProgress):
                lastProgress = scannerProgress
            case let .completed(snapshot):
                completedSnapshot = snapshot
            case .failed:
                XCTFail("scan must not fail")
            }
        }

        XCTAssertNotNil(completedSnapshot)
        XCTAssertEqual(completedSnapshot?.scannedItemCount, StorageFindingKind.allCases.count)
        XCTAssertTrue(lastProgress.allSatisfy { $0.state == .completed || $0.state == .skipped })
    }
}
