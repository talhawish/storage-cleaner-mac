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

    // MARK: - Bun & Deno

    func testBunToolchainInstallsAreDetected() throws {
        _ = try makeDir("home/.bun/install/install/1.1.0")
        _ = try makeDir("home/.bun/install/install/1.1.30")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let bun = try XCTUnwrap(group(groups, runtime: .node, source: .bun))
        XCTAssertEqual(bun.items.first?.versionLabel, "1.1.30")
        XCTAssertEqual(bun.olderItems.count, 1)
    }

    func testDenoVersionedBinariesAreDetected() throws {
        let denoBin = try makeDir("home/.deno/bin")
        try Data().write(to: denoBin.appendingPathComponent("deno-1.45.0"))
        try Data().write(to: denoBin.appendingPathComponent("deno-1.46.5"))

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let deno = try XCTUnwrap(group(groups, runtime: .deno, source: .denoBin))
        XCTAssertEqual(deno.items.first?.versionLabel, "1.46.5")
        XCTAssertEqual(deno.olderItems.count, 1)
    }

    // MARK: - PHP (Herd & phpenv)

    func testHerdPhpInstallsAreDetected() throws {
        _ = try makeDir("home/Library/Application Support/Herd/config/php")
        _ = try makeDir("home/Library/Application Support/Herd/config/php/8.2")
        _ = try makeDir("home/Library/Application Support/Herd/config/php/8.3")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let php = try XCTUnwrap(group(groups, runtime: .php, source: .herd))
        XCTAssertEqual(php.items.first?.versionLabel, "8.3")
        XCTAssertEqual(php.olderItems.count, 1)
    }

    func testPhpenvVersionsAreDetected() throws {
        _ = try makeDir("home/.phpenv/versions/8.1.27")
        _ = try makeDir("home/.phpenv/versions/8.2.13")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let php = try XCTUnwrap(group(groups, runtime: .php, source: .phpenv))
        XCTAssertEqual(php.items.first?.versionLabel, "8.2.13")
        XCTAssertEqual(php.olderItems.count, 1)
    }

    // MARK: - .NET arm64 layout

    func testDotNetSdkAlternateLayoutIsDetected() throws {
        _ = try makeDir("home/.dotnet/x64/sdk/8.0.300")
        _ = try makeDir("home/.dotnet/x64/sdk/8.0.400")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let dotnet = try XCTUnwrap(group(groups, runtime: .dotnet, source: .dotnet))
        XCTAssertEqual(dotnet.items.count, 2)
    }

    // MARK: - Flutter (FVM & hand-clones)

    func testFvmFlutterVersionsAreDetected() throws {
        _ = try makeDir("home/fvm/versions/3.19.5")
        _ = try makeDir("home/fvm/versions/3.22.0")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let flutter = try XCTUnwrap(group(groups, runtime: .flutter, source: .fvm))
        XCTAssertEqual(flutter.items.first?.versionLabel, "3.22.0")
        XCTAssertEqual(flutter.olderItems.count, 1)
    }

    func testDevelopmentFvmFlutterVersionsAreDetected() throws {
        _ = try makeDir("home/development/fvm/versions/3.19.5")
        _ = try makeDir("home/development/fvm/versions/3.22.0")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let flutter = try XCTUnwrap(group(groups, runtime: .flutter, source: .fvm))
        XCTAssertEqual(flutter.items.count, 2)
    }

    func testHandClonedFlutterSdksAreDetected() throws {
        // Two hand-cloned SDKs at different version directories, so a multi-version
        // group is created. (Single-version installs are intentionally hidden — there
        // is nothing to clean up.)
        let stableRoot = try makeDir("home/development/flutter")
        try Data("3.22.0\n".utf8).write(to: stableRoot.appendingPathComponent("version"))
        _ = try makeDir("home/development/flutter/bin")
        let stableBin = stableRoot.appendingPathComponent("bin/flutter")
        FileManager.default.createFile(atPath: stableBin.path, contents: nil)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stableBin.path
        )

        let devRoot = try makeDir("home/flutter")
        try Data("3.24.0-1.1.pre\n".utf8).write(to: devRoot.appendingPathComponent("version"))
        _ = try makeDir("home/flutter/bin")
        let devBin = devRoot.appendingPathComponent("bin/flutter")
        FileManager.default.createFile(atPath: devBin.path, contents: nil)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: devBin.path
        )

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let flutter = try XCTUnwrap(group(groups, runtime: .flutter, source: .flutterSdk))
        XCTAssertEqual(flutter.items.count, 2)
    }

    // MARK: - Haskell (GHCup & Stack)

    func testGhcupGhcToolchainsAreDetected() throws {
        _ = try makeDir("home/.ghcup/ghc/9.4.7")
        _ = try makeDir("home/.ghcup/ghc/9.6.4")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let haskell = try XCTUnwrap(group(groups, runtime: .haskell, source: .ghcup))
        XCTAssertEqual(haskell.items.first?.versionLabel, "9.6.4")
        XCTAssertEqual(haskell.olderItems.count, 1)
    }

    func testStackGhcInstallsAreDetected() throws {
        _ = try makeDir("home/.stack/programs/x86_64-osx/ghc-9.4.7")
        _ = try makeDir("home/.stack/programs/x86_64-osx/ghc-9.6.4")
        _ = try makeDir("home/.stack/programs/aarch64-osx/ghc-9.4.7")

        let groups = RuntimeVersionCatalog.discoverGroups(environment: environment())
        let haskell = try XCTUnwrap(group(groups, runtime: .haskell, source: .stack))
        XCTAssertEqual(haskell.items.count, 2, "Same version on different arches collapses")
    }
}
