import XCTest
@testable import StorageCleaner

final class DependencyPathsTests: XCTestCase {
    func testProjectActivitySearchStartsAtHomeFolder() {
        let home = DependencyPaths.home(".").standardizedFileURL
        let roots = DependencyPaths.Projects.activitySearchRoots.map(\.standardizedFileURL)

        XCTAssertEqual(roots.first, home)
        XCTAssertEqual(DependencyPaths.Projects.activityMaxDepth, Int.max)
        XCTAssertEqual(DependencyPaths.Projects.activityMinimumProjectSize, 0)
    }

    func testGradleCacheIsOwnedByGradleNotAndroid() {
        let gradleCache = DependencyPaths.home(".gradle/caches").standardizedFileURL
        let wrapperDistributions = DependencyPaths.home(".gradle/wrapper/dists").standardizedFileURL
        let mavenRepository = DependencyPaths.home(".m2/repository").standardizedFileURL
        let paths = DependencyPaths.Gradle.cacheDirs.map { $0.standardizedFileURL.path }

        XCTAssertTrue(
            paths.contains(gradleCache.path),
            "Gradle cache must be scanned by the Gradle dependency scanner."
        )
        XCTAssertTrue(paths.contains(wrapperDistributions.path), "downloaded Gradle distributions are reclaimable")
        XCTAssertTrue(paths.contains(mavenRepository.path), "the default Maven repository must be scanned")
        XCTAssertTrue(DependencyPaths.Gradle.cacheDirStrings.contains("~/.gradle/caches"))
        XCTAssertTrue(DependencyPaths.Gradle.cacheDirStrings.contains("~/.gradle/wrapper/dists"))
        XCTAssertTrue(DependencyPaths.Gradle.cacheDirStrings.contains("~/.m2/repository"))
        XCTAssertFalse(
            DependencyPaths.Android.cacheDirs.map { $0.standardizedFileURL.path }.contains(gradleCache.path),
            "Android scanner must not also scan ~/.gradle/caches, or dashboard totals double-count it."
        )
    }

    func testAndroidSDKRootIsNotCountedAgainThroughNestedSystemImagesPath() {
        let sdk = DependencyPaths.home("Library/Android/sdk").standardizedFileURL
        let systemImages = DependencyPaths.home("Library/Android/sdk/system-images").standardizedFileURL
        let paths = DependencyPaths.Android.cacheDirs.map { $0.standardizedFileURL.path }

        XCTAssertTrue(paths.contains(sdk.path))
        XCTAssertFalse(paths.contains(systemImages.path), "the SDK root already includes every system image")
    }
}
