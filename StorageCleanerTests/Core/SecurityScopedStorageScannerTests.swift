import Foundation
import XCTest
@testable import StorageCleaner

final class SecurityScopedStorageScannerTests: XCTestCase {
    func testScanFailsBeforeTouchingScannerWhenHomeScopeIsMissing() async {
        let baseScanner = RecordingSecurityScopedScanner()
        let scanner = SecurityScopedStorageScanner(
            scanner: baseScanner,
            permissionHandler: FixedSecurityScopePermissionHandler(access: nil)
        )

        var iterator = scanner.scanEvents(for: [.largeFiles]).makeAsyncIterator()
        let event = await iterator.next()

        guard case let .failed(message) = event else {
            return XCTFail("Expected failed event")
        }
        XCTAssertTrue(message.contains("Home Folder access is required"))
        XCTAssertFalse(baseScanner.didScan)
    }

    func testScanForwardsEventsWhenHomeScopeIsActive() async {
        let baseScanner = RecordingSecurityScopedScanner()
        let scanner = SecurityScopedStorageScanner(
            scanner: baseScanner,
            permissionHandler: FixedSecurityScopePermissionHandler(
                access: SecurityScopedResourceAccess(
                    url: URL(filePath: "/Users/test"),
                    didStartAccessing: false
                )
            )
        )

        var iterator = scanner.scanEvents(for: [.screenshots]).makeAsyncIterator()
        let event = await iterator.next()

        guard case let .completed(snapshot) = event else {
            return XCTFail("Expected completed event")
        }
        XCTAssertEqual(snapshot.scannedItemCount, 1)
        XCTAssertTrue(baseScanner.didScan)
        XCTAssertEqual(baseScanner.requestedKinds, [.screenshots])
    }
}

private final class RecordingSecurityScopedScanner: @unchecked Sendable, StorageScanning {
    private let lock = NSLock()
    private var protectedDidScan = false
    private var protectedRequestedKinds: Set<StorageFindingKind>?

    var didScan: Bool {
        lock.withLock { protectedDidScan }
    }

    var requestedKinds: Set<StorageFindingKind>? {
        lock.withLock { protectedRequestedKinds }
    }

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        lock.withLock {
            protectedDidScan = true
            protectedRequestedKinds = kinds
        }

        return AsyncStream { continuation in
            continuation.yield(
                .completed(
                    ScanSnapshot(
                        findings: [],
                        scannedItemCount: 1,
                        duration: .seconds(1)
                    )
                )
            )
            continuation.finish()
        }
    }
}

private struct FixedSecurityScopePermissionHandler: StoragePermissionHandling {
    let access: SecurityScopedResourceAccess?

    func currentStatuses() -> [StoragePermissionStatus] {
        []
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        access
    }
}
