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

    func testGitStatusDetectsRepoAndUncommittedChanges() throws {
        let root = temporaryDirectory.appending(path: "git_project", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let initProcess = Process()
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initProcess.arguments = ["-C", root.path, "init"]
        try initProcess.run()
        initProcess.waitUntilExit()

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try "tracked-content".write(to: root.appending(path: "file.js"), atomically: true, encoding: .utf8)

        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["-C", root.path, "add", "file.js"]
        try addProcess.run()
        addProcess.waitUntilExit()

        try "modified-content".write(to: root.appending(path: "file.js"), atomically: true, encoding: .utf8)

        let status = GitStatusDetector.detect(at: root)
        XCTAssertTrue(status.isRepo)
        XCTAssertTrue(status.hasUncommittedChanges)
        XCTAssertFalse(status.hasUnpushedCommits, "no remote configured yet")
        XCTAssertTrue(status.hasPendingWork)
    }

    func testGitStatusDetectsCleanRepo() throws {
        let root = temporaryDirectory.appending(path: "clean_git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let initProcess = Process()
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initProcess.arguments = ["-C", root.path, "init"]
        try initProcess.run()
        initProcess.waitUntilExit()

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)

        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["-C", root.path, "add", "."]
        try addProcess.run()
        addProcess.waitUntilExit()

        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = [
            "-C", root.path, "-c", "user.name=test",
            "-c", "user.email=test@test.com", "commit", "-m", "init"
        ]
        try commitProcess.run()
        commitProcess.waitUntilExit()

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

    func testScannerPropagatesGitStatusToProjectInfo() async throws {
        let root = temporaryDirectory.appending(path: "scanned_git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let initProcess = Process()
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initProcess.arguments = ["-C", root.path, "init"]
        try initProcess.run()
        initProcess.waitUntilExit()

        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 1000).write(to: root.appending(path: "index.js"))

        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["-C", root.path, "add", "."]
        try addProcess.run()
        addProcess.waitUntilExit()

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
