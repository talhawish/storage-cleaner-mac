import XCTest
@testable import StorageCleaner

/// Regression coverage for the cleanup-audit infrastructure that backs the
/// Quick Clean → browser cache → Cleanup History flow.
final class CleanupAuditAttributionTests: XCTestCase {
    // MARK: - CleanupOptionsRegistry.storageKind(forURL:)

    /// The browser-cache lookup is the hot path for Quick Clean's most common
    /// case. Verify the seven real cache roots resolve to `.browserCaches`,
    /// not to any other kind the prefix could plausibly match.
    func testStorageKindResolvesEveryBrowserCacheRoot() {
        let roots = DependencyPaths.Browser.cacheDirs
        XCTAssertFalse(roots.isEmpty, "fixture should have at least one browser cache root")

        for url in roots {
            let resolved = CleanupOptionsRegistry.storageKind(forURL: url)
            XCTAssertEqual(
                resolved,
                .browserCaches,
                "Expected \(url.path) to resolve to .browserCaches, got \(String(describing: resolved))"
            )
        }
    }

    /// A child file inside a cache root (e.g. a Chrome profile's
    /// `Cache/Cache_Data/data_0`) must still resolve to the parent option's
    /// `storageKind`. This is what lets Quick Clean delete a whole cache
    /// directory and still leave a `.browserCaches` audit entry.
    func testStorageKindResolvesDescendantOfBrowserCacheRoot() {
        let chromeRoot = DependencyPaths.Browser.cacheDirs.first { url in
            url.lastPathComponent == "Chrome"
        }
        let childFile = chromeRoot?
            .appending(path: "Default/Cache/Cache_Data/data_0", directoryHint: .notDirectory)

        let target = childFile ?? URL(fileURLWithPath: "/tmp/nonexistent")
        XCTAssertEqual(
            CleanupOptionsRegistry.storageKind(forURL: target),
            .browserCaches
        )
    }

    /// Sibling paths that share a prefix character-for-character but are not
    /// descendants of the option path must NOT be attributed to that option.
    /// Without the trailing-`/` guard, "Chrome" would falsely claim "ChromeX".
    func testStorageKindDoesNotMatchPrefixWithoutSeparator() {
        let chromeRoot = DependencyPaths.Browser.cacheDirs.first { url in
            url.lastPathComponent == "Chrome"
        }
        let chromeSibling = chromeRoot?
            .deletingLastPathComponent()
            .appending(path: "ChromeX", directoryHint: .isDirectory)
        let target = chromeSibling ?? URL(fileURLWithPath: "/tmp/ChromeX")
        XCTAssertNil(
            CleanupOptionsRegistry.storageKind(forURL: target),
            "ChromeX is not a descendant of Chrome; lookup must not return .browserCaches"
        )
    }

    /// A path that no registered option owns must return `nil` so the caller
    /// can fall back to `.junkFiles` (or skip the audit, depending on policy).
    func testStorageKindReturnsNilForUnownedPath() {
        let url = URL(fileURLWithPath: "/Users/example/Documents/random.txt")
        XCTAssertNil(CleanupOptionsRegistry.storageKind(forURL: url))
    }

    // MARK: - Path-source-of-truth invariant

    /// The dashboard scanner and Quick Clean registry must agree on the
    /// browser cache locations. If they ever drift, a new browser would be
    /// detected by one surface and missed by the other. This test fails
    /// loudly the moment someone hand-edits either list.
    func testBrowserCachePathsStayInSyncBetweenScannerAndQuickClean() {
        let scannerPaths = Set(
            DependencyPaths.Browser.cacheDirs.map { $0.standardizedFileURL.path }
        )
        guard let browserOption = CleanupOptionsRegistry.option(byID: "browser-cache") else {
            return XCTFail("CleanupOptionsRegistry is missing the 'browser-cache' option")
        }
        let registryPaths = Set(browserOption.paths.compactMap { path -> String? in
            let expanded = UserHomeDirectory.expandingTilde(in: path)
            return expanded.isEmpty ? nil : URL(fileURLWithPath: expanded).standardizedFileURL.path
        })

        XCTAssertEqual(
            scannerPaths,
            registryPaths,
            "DependencyPaths.Browser.cacheDirs and the 'browser-cache' CleanupOption must stay in sync"
        )
        XCTAssertFalse(registryPaths.isEmpty, "browser-cache option must list at least one path")
    }
}
