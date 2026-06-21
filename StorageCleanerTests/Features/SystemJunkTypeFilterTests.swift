import XCTest
@testable import StorageCleaner

/// Verifies the type-filter logic that drives `SystemJunkView` — guards against the regression
/// where the default `.all` filter dropped every record because each kind's `filter(for:)`
/// returns a specific sub-type, never `.all`.
final class SystemJunkTypeFilterTests: XCTestCase {
    func testAllFilterContainsEverySystemJunkKind() {
        XCTAssertTrue(SystemJunkTypeFilter.all.contains(.orphanedAppSupport))
        XCTAssertTrue(SystemJunkTypeFilter.all.contains(.orphanedAppCaches))
        XCTAssertTrue(SystemJunkTypeFilter.all.contains(.orphanedAppContainers))
        XCTAssertTrue(SystemJunkTypeFilter.all.contains(.orphanedAppPreferences))
        XCTAssertTrue(SystemJunkTypeFilter.all.contains(.oldCrashReports))
    }

    func testSubTypeFilterOnlyMatchesItsOwnKind() {
        XCTAssertTrue(SystemJunkTypeFilter.appSupport.contains(.orphanedAppSupport))
        XCTAssertFalse(SystemJunkTypeFilter.appSupport.contains(.orphanedAppCaches))
        XCTAssertFalse(SystemJunkTypeFilter.appSupport.contains(.orphanedAppContainers))
        XCTAssertFalse(SystemJunkTypeFilter.appSupport.contains(.orphanedAppPreferences))
        XCTAssertFalse(SystemJunkTypeFilter.appSupport.contains(.oldCrashReports))

        XCTAssertTrue(SystemJunkTypeFilter.caches.contains(.orphanedAppCaches))
        XCTAssertFalse(SystemJunkTypeFilter.caches.contains(.orphanedAppSupport))

        XCTAssertTrue(SystemJunkTypeFilter.containers.contains(.orphanedAppContainers))
        XCTAssertFalse(SystemJunkTypeFilter.containers.contains(.orphanedAppSupport))

        XCTAssertTrue(SystemJunkTypeFilter.preferences.contains(.orphanedAppPreferences))
        XCTAssertFalse(SystemJunkTypeFilter.preferences.contains(.orphanedAppSupport))

        XCTAssertTrue(SystemJunkTypeFilter.crashReports.contains(.oldCrashReports))
        XCTAssertFalse(SystemJunkTypeFilter.crashReports.contains(.orphanedAppSupport))
    }

    func testFilterForKindMapsCorrectly() {
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .orphanedAppSupport), .appSupport)
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .orphanedAppCaches), .caches)
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .orphanedAppContainers), .containers)
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .orphanedAppPreferences), .preferences)
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .oldCrashReports), .crashReports)
    }

    func testFilterForNonSystemJunkKindFallsBackToAll() {
        // Non-system-junk kinds must not crash and should default to `.all` so a stray
        // finding passed in (e.g. a developer-storage kind) doesn't disappear silently.
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .xcodeArtifacts), .all)
        XCTAssertEqual(SystemJunkTypeFilter.filter(for: .trash), .all)
    }
}
