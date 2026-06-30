import XCTest
@testable import StorageCleaner

final class DependencyPathsTests: XCTestCase {
    func testGradleCacheIsOwnedByGradleNotAndroid() {
        let gradleCache = DependencyPaths.home(".gradle/caches").standardizedFileURL

        XCTAssertTrue(
            DependencyPaths.Gradle.cacheDirs.map(\.standardizedFileURL).contains(gradleCache),
            "Gradle cache must be scanned by the Gradle dependency scanner."
        )
        XCTAssertFalse(
            DependencyPaths.Android.cacheDirs.map(\.standardizedFileURL).contains(gradleCache),
            "Android scanner must not also scan ~/.gradle/caches, or dashboard totals double-count it."
        )
    }
}
