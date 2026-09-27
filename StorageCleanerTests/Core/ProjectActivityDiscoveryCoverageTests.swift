import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectActivityDiscoveryCoverageTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testDefaultScanIncludesTinyMarkerOnlyFolders() async throws {
        let root = temporaryDirectory.appending(path: "tiny_fixture", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "name: fixture".write(to: root.appending(path: "pubspec.yaml"), atomically: true, encoding: .utf8)
        try "void main() {}".write(to: root.appending(path: "main.dart"), atomically: true, encoding: .utf8)

        let snapshot = await ProjectActivityScanner(searchPaths: [temporaryDirectory]).scan()

        XCTAssertEqual(snapshot.projects.map(\.name), ["tiny_fixture"])
        XCTAssertGreaterThan(snapshot.projects[0].totalSize, 0)
    }

    func testDefaultScanFindsProjectsInHiddenDirectoriesBeyondSixLevels() async throws {
        let project = temporaryDirectory.appending(
            path: ".custom-work/nested/one/two/three/four/five/six/project",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try "// swift package".write(
            to: project.appending(path: "Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let snapshot = await ProjectActivityScanner(searchPaths: [temporaryDirectory]).scan()

        XCTAssertEqual(snapshot.projects.map(\.path.lastPathComponent), ["project"])
        XCTAssertEqual(snapshot.projects.first?.technology, .swift)
    }

    func testSearchRootCanItselfBeAProject() async throws {
        try "// swift package".write(
            to: temporaryDirectory.appending(path: "Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let snapshot = await ProjectActivityScanner(searchPaths: [temporaryDirectory]).scan()

        XCTAssertEqual(snapshot.projects.first?.path.standardizedFileURL, temporaryDirectory.standardizedFileURL)
    }

    func testHomeSearchPrunesInstalledDependencyTrees() async throws {
        let dependency = temporaryDirectory.appending(
            path: "unmarked/node_modules/nested-package",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: dependency, withIntermediateDirectories: true)
        try "name: dependency".write(
            to: dependency.appending(path: "pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )

        let snapshot = await ProjectActivityScanner(searchPaths: [temporaryDirectory]).scan()

        XCTAssertTrue(snapshot.projects.isEmpty)
    }
}
