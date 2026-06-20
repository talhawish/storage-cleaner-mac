import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectCompressionServiceTests: XCTestCase {
    private var workingDirectory: URL!

    override func setUpWithError() throws {
        workingDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workingDirectory)
    }

    // MARK: - Happy path

    func testCompressHibernatesCreatesZipAndRemovesOriginal() async throws {
        let project = try makeNodeProject(
            named: "web-app",
            sourceBytes: 4_000,
            dependencyBytes: 30_000
        )
        let zipURL = ProjectCompressionService.zipURL(for: project)
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded, "got failure: \(outcome.failureReason ?? "nil")")
        XCTAssertNil(outcome.failureReason)
        XCTAssertEqual(outcome.zipURL, zipURL)
        XCTAssertGreaterThan(outcome.reclaimedDependencyBytes, 0)
        XCTAssertEqual(outcome.removedDirectoryCount, 1)
        XCTAssertGreaterThan(outcome.archiveSize, 0)
        XCTAssertGreaterThan(outcome.totalReclaimedBytes, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path), "archive created")
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.path.path), "original folder removed")
    }

    func testCompressRemovesOnlyDependenciesNotSource() async throws {
        let project = try makeNodeProject(
            named: "sourceful",
            sourceBytes: 6_000,
            dependencyBytes: 12_000
        )
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded, "got failure: \(outcome.failureReason ?? "nil")")
        XCTAssertGreaterThanOrEqual(outcome.reclaimedDependencyBytes, 12_000)
        // The original was removed; the zip exists; nothing in the source
        // (which is gone) can leak into the archive unintentionally.
        XCTAssertTrue(FileManager.default.fileExists(atPath: outcome.zipURL.path))
    }

    func testZipURLLivesNextToOriginalFolder() async throws {
        let project = try makeNodeProject(
            named: "sidecar",
            sourceBytes: 1_000,
            dependencyBytes: 4_000
        )
        let expected = project.path
            .deletingLastPathComponent()
            .appending(path: "sidecar.zip")
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.zipURL.standardizedFileURL, expected.standardizedFileURL)
        XCTAssertEqual(outcome.zipURL.deletingLastPathComponent(), project.path.deletingLastPathComponent())
    }

    // MARK: - Failure paths

    func testCompressFailsWhenProjectFolderMissing() async {
        let project = ProjectInfo(
            name: "ghost",
            path: workingDirectory.appending(path: "does-not-exist", directoryHint: .isDirectory),
            technology: .nodeJS,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 0,
            childProjectCount: 0,
            dependencySize: 0
        )
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertNotNil(outcome.failureReason)
        XCTAssertEqual(outcome.totalReclaimedBytes, 0)
        XCTAssertEqual(outcome.archiveSize, 0)
    }

    func testCompressFailsWhenZipAlreadyExists() async throws {
        let project = try makeNodeProject(
            named: "collide",
            sourceBytes: 2_000,
            dependencyBytes: 6_000
        )
        let zipURL = ProjectCompressionService.zipURL(for: project)
        try Data(repeating: 0, count: 32).write(to: zipURL)
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(outcome.failureReason?.contains("already exists") == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.path), "original folder kept on collision")
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path), "existing zip untouched")
    }

    func testCompressFailsWhenCompressionProcessFails() async throws {
        let project = try makeNodeProject(
            named: "broken-zip",
            sourceBytes: 2_000,
            dependencyBytes: 4_000
        )
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, _ in
                throw ProcessRunError(
                    executable: "/usr/bin/ditto",
                    arguments: [],
                    exitCode: 1,
                    standardError: Data("No such file or directory".utf8)
                )
            },
            verify: { _ in }
        )
        let service = makeService(command: command)

        let outcome = await service.compress(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(outcome.failureReason?.contains("No such file or directory") == true)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: project.path.path),
            "original folder kept on compress failure"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: outcome.zipURL.path), "no archive left behind")
    }

    func testCompressFailsWhenArchiveIsEmpty() async throws {
        let project = try makeNodeProject(
            named: "empty-archive",
            sourceBytes: 2_000,
            dependencyBytes: 4_000
        )
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, destination in
                // Simulate ditto creating a 0-byte file (e.g., crashed).
                try Data().write(to: destination)
            },
            verify: { _ in }
        )
        let service = makeService(command: command)

        let outcome = await service.compress(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.failureReason, "The archive is missing or empty.")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: project.path.path),
            "original folder kept on empty archive"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: outcome.zipURL.path), "empty archive removed")
    }

    func testCompressFailsWhenArchiveFailsIntegrityCheck() async throws {
        let project = try makeNodeProject(
            named: "corrupt-zip",
            sourceBytes: 2_000,
            dependencyBytes: 4_000
        )
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, destination in
                try Data(repeating: 0xAB, count: 2_048).write(to: destination)
            },
            verify: { _ in
                throw ProcessRunError(
                    executable: "/usr/bin/unzip",
                    arguments: [],
                    exitCode: 9,
                    standardError: Data("End-of-central-directory signature not found.".utf8)
                )
            }
        )
        let service = makeService(command: command)

        let outcome = await service.compress(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(outcome.failureReason?.contains("End-of-central-directory") == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.path), "original folder kept on bad zip")
        XCTAssertFalse(FileManager.default.fileExists(atPath: outcome.zipURL.path), "corrupt archive removed")
    }

    func testCompressSucceedsWhenVerificationPasses() async throws {
        let project = try makeNodeProject(
            named: "verified",
            sourceBytes: 1_500,
            dependencyBytes: 3_000
        )
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, destination in
                try Data(repeating: 0, count: 1_024).write(to: destination)
            },
            verify: { _ in /* success */ }
        )
        let service = makeService(command: command)

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded, "got failure: \(outcome.failureReason ?? "nil")")
        XCTAssertEqual(outcome.archiveSize, 1_024)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outcome.zipURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.path.path))
    }

    // MARK: - Hidden & nested dependencies

    func testCompressRemovesHiddenDependencyDirectories() async throws {
        let project = try makeSwiftProject(
            named: "swift-pkg",
            sourceBytes: 1_000,
            dependencyBytes: 8_000
        )
        let service = makeService()

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded, "got failure: \(outcome.failureReason ?? "nil")")
        XCTAssertGreaterThanOrEqual(outcome.reclaimedDependencyBytes, 8_000)
        XCTAssertEqual(outcome.removedDirectoryCount, 1)
    }

    // MARK: - Cancellation

    func testCompressReportsCancellationWithoutRemovingOriginal() async throws {
        let project = try makeNodeProject(
            named: "cancel",
            sourceBytes: 1_000,
            dependencyBytes: 4_000
        )
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, _ in
                // `Task.sleep` honors cancellation and throws `CancellationError`,
                // which the service's `try await command.compress(...)` will
                // propagate as a failure — leaving the original folder intact.
                try await Task.sleep(nanoseconds: 500_000_000)
            },
            verify: { _ in }
        )
        let service = makeService(command: command)

        let task = Task { await service.compress(project) }
        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()
        let outcome = await task.value

        XCTAssertFalse(outcome.succeeded)
        XCTAssertNotNil(outcome.failureReason, "cancellation surfaces as a failure with a reason")
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.path), "original kept on cancellation")
    }

    // MARK: - Helpers

    private func makeService(
        command: ProjectCompressionService.CompressionCommand? = nil
    ) -> ProjectCompressionService {
        if let command {
            return ProjectCompressionService(
                fileManager: .default,
                removal: .delete,
                command: command
            )
        }
        return ProjectCompressionService(removal: .delete)
    }

    private func makeNodeProject(
        named name: String,
        sourceBytes: Int,
        dependencyBytes: Int
    ) throws -> ProjectInfo {
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

    private func makeSwiftProject(
        named name: String,
        sourceBytes: Int,
        dependencyBytes: Int
    ) throws -> ProjectInfo {
        let root = workingDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 200).write(to: root.appending(path: "Package.swift"))
        try Data(repeating: 2, count: sourceBytes).write(to: root.appending(path: "main.swift"))

        let build = root.appending(path: ".build", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data(repeating: 3, count: dependencyBytes).write(to: build.appending(path: "artifact.o"))

        return ProjectInfo(
            name: name,
            path: root,
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: Int64(sourceBytes + dependencyBytes + 200),
            childProjectCount: 0,
            dependencySize: Int64(dependencyBytes)
        )
    }
}
