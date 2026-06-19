import Foundation
import XCTest
@testable import StorageCleaner

final class CLINodeGlobalsTests: XCTestCase {
    private var nodeModules: URL!

    override func setUpWithError() throws {
        nodeModules = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: nodeModules.deletingLastPathComponent())
    }

    func testPackageEnumerationDescendsIntoScopesAndSkipsBin() throws {
        try makePackage("firebase-tools", manifest: #"{"name":"firebase-tools","bin":"firebase"}"#)
        try makePackage("plain-lib", manifest: #"{"name":"plain-lib"}"#)
        try makePackage(
            "@anthropic-ai/claude-code",
            manifest: #"{"name":"@anthropic-ai/claude-code","bin":{"claude":"x"}}"#
        )
        try FileManager.default.createDirectory(
            at: nodeModules.appendingPathComponent(".bin"),
            withIntermediateDirectories: true
        )

        let names = NodeGlobalCatalog.packageDirectories(in: nodeModules)
            .map(\.lastPathComponent)
            .sorted()

        XCTAssertEqual(names, ["claude-code", "firebase-tools", "plain-lib"])
    }

    func testPackageInfoReadsNameDescriptionAndBinAsString() throws {
        let dir = try makePackage(
            "firebase-tools",
            manifest: #"{"name":"firebase-tools","description":"Firebase CLI","bin":"firebase"}"#
        )

        let info = try XCTUnwrap(NodePackageInfo.read(at: dir, fileManager: .default))
        XCTAssertEqual(info.name, "firebase-tools")
        XCTAssertEqual(info.subtitle, "Firebase CLI")
        XCTAssertTrue(info.hasExecutable)
    }

    func testPackageInfoTreatsBinObjectAsExecutable() throws {
        let dir = try makePackage("codex", manifest: #"{"name":"codex","bin":{"codex":"cli.js"}}"#)
        let info = try XCTUnwrap(NodePackageInfo.read(at: dir, fileManager: .default))
        XCTAssertTrue(info.hasExecutable)
    }

    func testPackageInfoWithoutBinIsNotExecutable() throws {
        let dir = try makePackage("plain-lib", manifest: #"{"name":"plain-lib"}"#)
        let info = try XCTUnwrap(NodePackageInfo.read(at: dir, fileManager: .default))
        XCTAssertFalse(info.hasExecutable)
        XCTAssertEqual(info.subtitle, "Global npm package")
    }

    func testPackageInfoReturnsNilWithoutManifest() {
        let dir = nodeModules.appendingPathComponent("ghost")
        XCTAssertNil(NodePackageInfo.read(at: dir, fileManager: .default))
    }

    func testNpxCacheIsNamedAfterItsPrimaryDependency() throws {
        let npxRoot = nodeModules.deletingLastPathComponent().appendingPathComponent("_npx", isDirectory: true)
        let cache = npxRoot.appendingPathComponent("abc123", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let manifest = #"{"dependencies":{"firebase-tools":"^13.0.0"}}"#
        try Data(manifest.utf8).write(to: cache.appendingPathComponent("package.json"))

        let programs = NodeGlobalCatalog.npxCachedPrograms(root: npxRoot)
        XCTAssertEqual(programs.map(\.displayName), ["firebase-tools"])
        XCTAssertEqual(programs.first?.safety, .safe)
        XCTAssertEqual(programs.first?.category, .packageCache)
        XCTAssertEqual(programs.first?.url.resolvingSymlinksInPath(), cache.resolvingSymlinksInPath())
    }

    @discardableResult
    private func makePackage(_ name: String, manifest: String) throws -> URL {
        let dir = nodeModules.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(manifest.utf8).write(to: dir.appendingPathComponent("package.json"))
        return dir
    }
}
