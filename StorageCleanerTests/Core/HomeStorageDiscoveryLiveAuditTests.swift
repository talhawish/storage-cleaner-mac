import Foundation
import XCTest
@testable import StorageCleaner

/// Opt-in, read-only timing against the current user's accessible Home folder.
/// Ordinary regression runs use synthetic fixtures and never walk Home here.
final class HomeStorageDiscoveryLiveAuditTests: XCTestCase {
    func testReadOnlyHomeInventory() async throws {
        guard ProcessInfo.processInfo.environment["STORAGE_CLEANER_LIVE_AUDIT"] == "1" else {
            throw XCTSkip("Set STORAGE_CLEANER_LIVE_AUDIT=1 to measure live Home discovery")
        }
        let started = ContinuousClock.now
        let report = await HomeStorageDiscoveryCache().discover()
        print("Home inventory: \(started.duration(to: .now)); \(report.inspectedItemCount) entries; "
            + "\(report.result.unreadableItemCount) unreadable locations; "
            + "\(report.result.largeFolders.count) folders; \(report.result.localAIModels.count) models")
        for candidate in report.result.largeFolders.prefix(10) {
            print("Folder: \(candidate.url.path) — \(candidate.bytes) bytes")
        }
        for candidate in report.result.localAIModels.prefix(10) {
            print("Model: \(candidate.url.path) — \(candidate.bytes) bytes")
        }
        XCTAssertGreaterThan(report.inspectedItemCount, 0)
    }
}
