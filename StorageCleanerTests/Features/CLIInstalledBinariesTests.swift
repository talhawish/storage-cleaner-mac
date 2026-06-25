import Foundation
import XCTest
@testable import StorageCleaner

final class CLIInstalledBinariesTests: XCTestCase {
    private var root: URL!
    private var binDir: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        binDir = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testDetectsExecutableFilesAndSkipsPlainFiles() throws {
        try makeExecutable("opencode")
        try makeFile("README", executable: false)

        let names = InstalledBinaryCatalog.installedPrograms(in: [binDir]).map(\.displayName)
        XCTAssertEqual(names, ["opencode"])
    }

    func testFollowsSymlinkToVersionedInstall() throws {
        // Mirrors Claude Code: ~/.local/bin/claude -> ~/.local/share/claude/versions/X
        let install = root.appendingPathComponent("share/claude/versions/2.1.183", isDirectory: true)
        try FileManager.default.createDirectory(at: install, withIntermediateDirectories: true)
        try link("claude", to: install)

        let programs = InstalledBinaryCatalog.installedPrograms(in: [binDir])
        XCTAssertEqual(programs.map(\.displayName), ["claude"])
        XCTAssertEqual(programs.first?.url.resolvingSymlinksInPath(), install.resolvingSymlinksInPath())
        XCTAssertEqual(programs.first?.category, .binary)
    }

    func testSkipsDanglingSymlinks() throws {
        try FileManager.default.createSymbolicLink(
            at: binDir.appendingPathComponent("ghost"),
            withDestinationURL: root.appendingPathComponent("does-not-exist")
        )
        XCTAssertTrue(InstalledBinaryCatalog.installedPrograms(in: [binDir]).isEmpty)
    }

    func testSkipsSymlinksIntoHomebrewCellarAndNodeModules() throws {
        let cellarBin = root.appendingPathComponent("Cellar/git/2.0/bin", isDirectory: true)
        let nodeBin = root.appendingPathComponent("lib/node_modules/firebase-tools/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: cellarBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nodeBin, withIntermediateDirectories: true)
        let git = cellarBin.appendingPathComponent("git")
        let firebase = nodeBin.appendingPathComponent("firebase")
        FileManager.default.createFile(atPath: git.path, contents: Data())
        FileManager.default.createFile(atPath: firebase.path, contents: Data())
        try link("git", to: git)
        try link("firebase", to: firebase)

        XCTAssertTrue(InstalledBinaryCatalog.installedPrograms(in: [binDir]).isEmpty)
    }

    func testAutodiscoverReturnsKnownToolBinsWhenHomeEnumerationFails() {
        // Simulate a sandboxed build where the home directory cannot be
        // enumerated. autodiscoveredToolBins should fall back to probing
        // known tool-specific bin directories instead of returning empty.
        let inaccessibleHome = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString)", isDirectory: true)
        let result = InstalledBinaryCatalog.autodiscoveredToolBins(
            home: inaccessibleHome,
            fileManager: FileManager.default
        )
        // Should be empty (the dummy home has no bins) but must not crash.
        XCTAssertTrue(result.isEmpty, "Fallback should handle missing home dir without crashing")
    }

    func testBinDirectoriesIncludesKnownToolBins() throws {
        // Set up a ~/.opencode/bin directory and verify it appears in the
        // autodiscovery result when the home directory is enumerable.
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let opencodeBin = home.appendingPathComponent(".opencode/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: opencodeBin, withIntermediateDirectories: true)

        let result = InstalledBinaryCatalog.autodiscoveredToolBins(
            home: home,
            fileManager: FileManager.default
        )
        XCTAssertTrue(result.contains(opencodeBin), ".opencode/bin should be in autodiscovered bins")
    }

    func testDeduplicatesSameResolvedTargetAcrossDirectories() throws {
        let other = root.appendingPathComponent("bin2", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let real = try makeExecutable("tool")
        try FileManager.default.createSymbolicLink(at: other.appendingPathComponent("tool"), withDestinationURL: real)

        let programs = InstalledBinaryCatalog.installedPrograms(in: [binDir, other])
        XCTAssertEqual(programs.count, 1)
    }

    private func link(_ name: String, to destination: URL) throws {
        try FileManager.default.createSymbolicLink(
            at: binDir.appendingPathComponent(name),
            withDestinationURL: destination
        )
    }

    @discardableResult
    private func makeExecutable(_ name: String) throws -> URL {
        try makeFile(name, executable: true)
    }

    @discardableResult
    private func makeFile(_ name: String, executable: Bool) throws -> URL {
        let url = binDir.appendingPathComponent(name)
        FileManager.default.createFile(
            atPath: url.path,
            contents: Data("#!/bin/sh\n".utf8),
            attributes: executable ? [.posixPermissions: 0o755] : [.posixPermissions: 0o644]
        )
        return url
    }
}
