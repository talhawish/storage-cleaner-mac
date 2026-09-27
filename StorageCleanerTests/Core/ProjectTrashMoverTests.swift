import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectTrashMoverTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testHibernationUsesSharedTrashMoverForDependencies() async throws {
        let project = try makeProject(named: "hibernate")
        let mover = ProjectRecordingTrashMover(destinationDirectory: root.appending(path: "recycled"))
        let service = ProjectHibernationService(removal: .trash, trashMover: mover)

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(mover.sources.map(\.lastPathComponent), ["node_modules"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.appending(path: "index.js").path))
    }

    func testCompressionUsesSharedTrashMoverForDependenciesAndOriginal() async throws {
        let project = try makeProject(named: "compress")
        let mover = ProjectRecordingTrashMover(destinationDirectory: root.appending(path: "recycled"))
        let command = ProjectCompressionService.CompressionCommand(
            compress: { _, archive in try Data("archive".utf8).write(to: archive) },
            verify: { _ in }
        )
        let service = ProjectCompressionService(
            removal: .trash,
            command: command,
            trashMover: mover
        )

        let outcome = await service.compress(project)

        XCTAssertTrue(outcome.succeeded, outcome.failureReason ?? "")
        XCTAssertEqual(mover.sources.map(\.lastPathComponent), ["node_modules", "compress"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outcome.zipURL.path))
    }

    private func makeProject(named name: String) throws -> ProjectInfo {
        let directory = root.appending(path: name, directoryHint: .isDirectory)
        let dependencies = directory.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dependencies, withIntermediateDirectories: true)
        try "{}".write(to: directory.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 1_024).write(to: directory.appending(path: "index.js"))
        try Data(repeating: 2, count: 4_096).write(to: dependencies.appending(path: "package.bin"))
        return ProjectInfo(
            name: name,
            path: directory,
            technology: .nodeJS,
            lastModifiedDate: .distantPast,
            totalSize: 5_120,
            childProjectCount: 0,
            dependencySize: 4_096
        )
    }

}

private final class ProjectRecordingTrashMover: TrashMoving, @unchecked Sendable {
    private let lock = NSLock()
    private let destinationDirectory: URL
    private var recordedSources: [URL] = []

    init(destinationDirectory: URL) {
        self.destinationDirectory = destinationDirectory
    }

    var sources: [URL] { lock.withLock { recordedSources } }

    func moveToTrash(_ urls: [URL]) async -> TrashMoveResult {
        var destinations: [URL: URL] = [:]
        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            for url in urls {
                let destination = destinationDirectory.appending(path: UUID().uuidString)
                try FileManager.default.moveItem(at: url, to: destination)
                destinations[url] = destination
                lock.withLock { recordedSources.append(url) }
            }
            return TrashMoveResult(destinationBySource: destinations, error: nil)
        } catch {
            return TrashMoveResult(destinationBySource: destinations, error: error)
        }
    }
}
