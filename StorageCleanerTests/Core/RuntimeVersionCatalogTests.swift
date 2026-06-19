import Foundation
import XCTest
@testable import StorageCleaner

final class RuntimeVersionCatalogTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helpers

    private func makeDir(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func environment(cellars: [URL] = [], jvm: URL? = nil) -> RuntimeVersionCatalog.Environment {
        RuntimeVersionCatalog.Environment(
            home: root.appendingPathComponent("home", isDirectory: true),
            homebrewCellars: cellars,
            jvmDirectory: jvm ?? root.appendingPathComponent("no-jvm", isDirectory: true)
        )
    }

    private func group(
        _ groups: [RuntimeVersionGroup],
        runtime: DevRuntime,
        source: VersionSource
    ) -> RuntimeVersionGroup? {
        groups.first { $0.runtime == runtime && $0.source == source }
    }

    // MARK: - Version managers

    func testNvmWithMultipleNodeVersionsBecomesAGroupWithNewestKept() throws {
        _ = try makeDir("home/.nvm/versions/node/v18.20.4")
        _ = try makeDir("home/.nvm/versions/node/v20.11.1")
        _ = try makeDir("home/.nvm/versions/node/v16.10.0")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let node = try XCTUnwrap(group(groups, runtime: .node, source: .nvm))

        XCTAssertEqual(node.items.count, 3)
        XCTAssertEqual(node.items.first?.versionLabel, "v20.11.1")
        XCTAssertTrue(node.items.first?.isNewest == true)
        XCTAssertEqual(node.olderItems.count, 2)
        XCTAssertFalse(node.olderItems.contains { $0.versionLabel == "v20.11.1" })
    }

    func testSingleVersionRuntimeIsNotSurfaced() throws {
        _ = try makeDir("home/.pyenv/versions/3.11.4")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        XCTAssertNil(group(groups, runtime: .python, source: .pyenv))
    }

    func testSymlinkedAliasesAreNotCountedAsVersions() throws {
        let versions = try makeDir("home/.rbenv/versions")
        _ = try makeDir("home/.rbenv/versions/3.2.2")
        _ = try makeDir("home/.rbenv/versions/3.3.0")
        // rbenv keeps a `default`-style alias as a symlink, which must be ignored.
        try FileManager.default.createSymbolicLink(
            at: versions.appendingPathComponent("current"),
            withDestinationURL: versions.appendingPathComponent("3.3.0")
        )

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let ruby = try XCTUnwrap(group(groups, runtime: .ruby, source: .rbenv))
        XCTAssertEqual(ruby.items.count, 2)
    }

    // MARK: - Homebrew versioned formulae

    func testHomebrewVersionedFormulaeGroupByBaseName() throws {
        let cellar = try makeDir("brew/Cellar")
        _ = try makeDir("brew/Cellar/php@8.1/8.1.29")
        _ = try makeDir("brew/Cellar/php@8.2/8.2.10")
        _ = try makeDir("brew/Cellar/git/2.44.0") // unrelated, single, ignored

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment(cellars: [cellar]))
        let php = try XCTUnwrap(group(groups, runtime: .php, source: .homebrew))

        XCTAssertEqual(php.items.count, 2)
        // Newest keeps the higher inner version (8.2.10) and removal targets the keg directory.
        XCTAssertEqual(php.items.first?.url.lastPathComponent, "php@8.2")
        XCTAssertEqual(php.olderItems.first?.url.lastPathComponent, "php@8.1")
        XCTAssertNil(group(groups, runtime: .golang, source: .homebrew))
    }

    // MARK: - System JDKs

    func testJDKsAreDetectedButFlaggedForManualRemoval() throws {
        let jvm = try makeDir("Library/Java")
        _ = try makeDir("Library/Java/temurin-17.0.2.jdk")
        _ = try makeDir("Library/Java/temurin-21.0.1.jdk")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment(jvm: jvm))
        let java = try XCTUnwrap(group(groups, runtime: .java, source: .jvm))

        XCTAssertEqual(java.items.count, 2)
        XCTAssertEqual(java.items.first?.versionLabel, "temurin-21.0.1")
        XCTAssertTrue(java.source.requiresManualRemoval)
    }

    func testGoenvVersionsAreDetected() throws {
        _ = try makeDir("home/.goenv/versions/1.21.7")
        _ = try makeDir("home/.goenv/versions/1.22.3")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let golang = try XCTUnwrap(group(groups, runtime: .golang, source: .goenv))

        XCTAssertEqual(golang.items.map(\.versionLabel), ["1.22.3", "1.21.7"])
        XCTAssertEqual(golang.olderItems.map(\.versionLabel), ["1.21.7"])
    }

    func testDotNetSdkVersionsAreDetected() throws {
        _ = try makeDir("home/.dotnet/sdk/8.0.204")
        _ = try makeDir("home/.dotnet/sdk/9.0.100-preview.4")
        _ = try makeDir("home/.dotnet/sdk/9.0.100")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let dotnet = try XCTUnwrap(group(groups, runtime: .dotnet, source: .dotnet))

        XCTAssertEqual(dotnet.items.first?.versionLabel, "9.0.100")
        XCTAssertEqual(dotnet.olderItems.count, 2)
    }

    func testMiseInstallsAreDetectedAcrossRuntimes() throws {
        _ = try makeDir("home/.local/share/mise/installs/go/1.21.7")
        _ = try makeDir("home/.local/share/mise/installs/go/1.22.3")
        _ = try makeDir("home/.local/share/mise/installs/dotnet/8.0.204")
        _ = try makeDir("home/.local/share/mise/installs/dotnet/9.0.100")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let golang = try XCTUnwrap(group(groups, runtime: .golang, source: .mise))
        let dotnet = try XCTUnwrap(group(groups, runtime: .dotnet, source: .mise))

        XCTAssertEqual(golang.items.first?.versionLabel, "1.22.3")
        XCTAssertEqual(dotnet.items.first?.versionLabel, "9.0.100")
    }

    // MARK: - Sizing

    func testMeasuredFillsInByteSizes() throws {
        let oldVersion = try makeDir("home/.nvm/versions/node/v18.20.4")
        _ = try makeDir("home/.nvm/versions/node/v20.11.1")
        let payload = oldVersion.appendingPathComponent("file.bin")
        try Data(count: 4096).write(to: payload)

        let measured = RuntimeVersionCatalog.measured(
            RuntimeVersionCatalog.discoverGroups(environment: environment())
        )
        let node = try XCTUnwrap(group(measured, runtime: .node, source: .nvm))
        let older = try XCTUnwrap(node.items.first { $0.versionLabel == "v18.20.4" })
        XCTAssertGreaterThan(older.bytes, 0)
    }
}
