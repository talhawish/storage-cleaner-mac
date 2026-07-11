import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectActivityScannerGitTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    private func makeRepo(named name: String) throws -> URL {
        let root = temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try runGit(["init"], in: root)
        return root
    }

    private func runGit(_ arguments: [String], in root: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments
        try process.run()
        process.waitUntilExit()
    }

    private func commitAll(in root: URL) throws {
        try runGit(["add", "."], in: root)
        try runGit(
            ["-c", "user.name=test", "-c", "user.email=test@test.com", "commit", "-m", "init"],
            in: root
        )
    }

    func testGitStatusDetectsRepoAndUncommittedChanges() throws {
        let root = try makeRepo(named: "git_project")

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try "tracked-content".write(to: root.appending(path: "file.js"), atomically: true, encoding: .utf8)
        try runGit(["add", "file.js"], in: root)

        try "modified-content".write(to: root.appending(path: "file.js"), atomically: true, encoding: .utf8)

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertTrue(status.hasUncommittedChanges)
        XCTAssertFalse(status.hasUnpushedCommits, "no remote configured yet")
        XCTAssertTrue(status.hasPendingWork)
    }

    func testGitStatusDetectsCleanRepo() throws {
        let root = try makeRepo(named: "clean_git")

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try commitAll(in: root)

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertFalse(status.hasUncommittedChanges)
        XCTAssertFalse(status.hasUnpushedCommits)
        XCTAssertFalse(status.hasPendingWork)
    }

    func testGitStatusReturnsNotARepoWhenNoGitDirectory() {
        let root = temporaryDirectory.appending(path: "no_git", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let status = GitStatusDetector.detect(at: root)
        XCTAssertFalse(status.isRepo)
        XCTAssertFalse(status.hasPendingWork)
    }

    func testGitStatusHandlesFileMtimeOlderThanIndex() throws {
        let root = try makeRepo(named: "old_mtime")

        let fileURL = root.appending(path: "file.txt")
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(["add", "file.txt"], in: root)

        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 0)],
            ofItemAtPath: fileURL.path
        )

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertTrue(status.hasUncommittedChanges, "stat mismatch should be treated as modified")
    }

    func testGitStatusHandlesFileLargerThan4GB() throws {
        let root = try makeRepo(named: "huge_file")

        let fileURL = root.appending(path: "big.bin")
        try "x".write(to: fileURL, atomically: true, encoding: .utf8)
        try runGit(["add", "big.bin"], in: root)

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.truncate(atOffset: UInt64(UInt32.max) + 1)
        try handle.close()

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertTrue(status.hasUncommittedChanges)
    }

    func testGitStatusIgnoresSubmoduleDirectoryEntries() throws {
        let root = try makeRepo(named: "with_submodule")

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try commitAll(in: root)

        let gitlinkSHA = "da39a3ee5e6b4b0d3255bfef95601890afd80709"
        try runGit(["update-index", "--add", "--cacheinfo", "160000,\(gitlinkSHA),vendor"], in: root)
        try FileManager.default.createDirectory(
            at: root.appending(path: "vendor", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertFalse(status.hasUncommittedChanges, "gitlink entries must not read as modified files")
    }

    func testScannerPropagatesGitStatusToProjectInfo() async throws {
        let root = try makeRepo(named: "scanned_git")

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 1000).write(to: root.appending(path: "index.js"))
        try runGit(["add", "."], in: root)

        try "modified".write(to: root.appending(path: "index.js"), atomically: true, encoding: .utf8)

        let scanner = ProjectActivityScanner(
            searchPaths: [temporaryDirectory],
            maxDepth: 2,
            minimumProjectSize: 1
        )
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)
        XCTAssertTrue(project.gitStatus.isRepo)
        XCTAssertTrue(project.gitStatus.hasUncommittedChanges)
        XCTAssertTrue(project.gitStatus.hasPendingWork)
    }
}
