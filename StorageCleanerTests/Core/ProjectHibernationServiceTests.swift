import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectHibernationServiceTests: XCTestCase {
    private var workingDirectory: URL!
    private var service: ProjectHibernationService!

    override func setUpWithError() throws {
        workingDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        // Hard-delete in tests so fixtures stay self-contained and the real
        // Trash is never touched; production defaults to `.trash`.
        service = ProjectHibernationService(removal: .delete)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workingDirectory)
    }

    func testHibernateRemovesDependenciesAndKeepsSource() async throws {
        let project = try makeNodeProject(named: "web-app", sourceBytes: 8_000, dependencyBytes: 40_000)
        let dependencyDir = project.path.appending(path: "node_modules", directoryHint: .isDirectory)
        let sourceFile = project.path.appending(path: "index.js")

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertNil(outcome.failureReason)
        XCTAssertEqual(outcome.removedDirectoryCount, 1)
        XCTAssertEqual(outcome.reclaimedBytes, 40_000)
        // The project folder and its source survive; only dependencies are gone.
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.path), "project folder is kept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path), "source file is kept")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dependencyDir.path), "dependencies removed")
    }

    func testHibernateRemovesHiddenDependencyDirectories() async throws {
        // Swift's regenerable output (`.build`) is hidden and must still be reclaimed.
        let root = workingDirectory.appending(path: "swift-pkg", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_000).write(to: root.appending(path: "Package.swift"))
        let build = root.appending(path: ".build", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 25_000).write(to: build.appending(path: "artifact.o"))

        let project = ProjectInfo(
            name: "swift-pkg",
            path: root,
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 26_000,
            childProjectCount: 0,
            dependencySize: 25_000
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, 25_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: build.path), "hidden .build removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path))
    }

    func testHibernatePHPProjectUsesComposerVendorFallback() async throws {
        let root = workingDirectory.appending(path: "legacy-php", directoryHint: .isDirectory)
        let vendor = root.appending(path: "vendor", directoryHint: .isDirectory)
        let unrelatedVendor = root.appending(path: "tools/vendor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vendor, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedVendor, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_000).write(to: root.appending(path: "index.php"))
        try Data(repeating: 2, count: 18_000).write(to: vendor.appending(path: "autoload.php"))
        try Data(repeating: 3, count: 22_000).write(to: unrelatedVendor.appending(path: "dep.bin"))

        let project = ProjectInfo(
            name: "legacy-php",
            path: root,
            technology: .php,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 44_000,
            childProjectCount: 0,
            dependencySize: 18_000
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, 18_000)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vendor.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedVendor.path))
    }

    func testHibernateMissingProjectFails() async throws {
        let project = ProjectInfo(
            name: "ghost",
            path: workingDirectory.appending(path: "does-not-exist", directoryHint: .isDirectory),
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 100,
            childProjectCount: 0,
            dependencySize: 0
        )

        let outcome = await service.hibernate(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, 0)
        XCTAssertNotNil(outcome.failureReason)
    }

    func testHibernateWithNoDependenciesFails() async throws {
        let root = workingDirectory.appending(path: "lean", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 5, count: 3_000).write(to: root.appending(path: "main.swift"))
        let project = ProjectInfo(
            name: "lean",
            path: root,
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 3_000,
            childProjectCount: 0,
            dependencySize: 0
        )

        let outcome = await service.hibernate(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.removedDirectoryCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "main.swift").path))
    }

    func testHibernateBatchSummaryReportsReclaimedBytesAndFailures() async throws {
        let valid = try makeNodeProject(named: "valid", sourceBytes: 5_000, dependencyBytes: 12_000)
        let missing = ProjectInfo(
            name: "missing",
            path: workingDirectory.appending(path: "nope", directoryHint: .isDirectory),
            technology: .rust,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 4_096,
            childProjectCount: 0,
            dependencySize: 4_096
        )

        let summary = await service.hibernate([valid, missing])

        XCTAssertEqual(summary.outcomes.count, 2)
        XCTAssertEqual(summary.succeeded.count, 1)
        XCTAssertEqual(summary.failed.count, 1)
        XCTAssertEqual(summary.reclaimedBytes, 12_000, "only the reclaimed dependency bytes count")
        XCTAssertEqual(summary.succeeded.first?.project.name, "valid")
        XCTAssertEqual(summary.failed.first?.project.name, "missing")
    }

    // MARK: - Helpers

    private func makeNodeProject(named name: String, sourceBytes: Int, dependencyBytes: Int) throws -> ProjectInfo {
        let root = workingDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 7, count: sourceBytes).write(to: root.appending(path: "index.js"))

        let modules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        try Data(repeating: 8, count: dependencyBytes).write(to: modules.appending(path: "dep.js"))

        return ProjectInfo(
            name: name,
            path: root,
            technology: .nodeJS,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: Int64(sourceBytes + dependencyBytes + 2),
            childProjectCount: 0,
            dependencySize: Int64(dependencyBytes)
        )
    }
}
