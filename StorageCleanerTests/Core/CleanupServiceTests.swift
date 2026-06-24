import Foundation
import XCTest
@testable import StorageCleaner

final class CleanupServiceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var trashedURLs: [URL] = []

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        for url in trashedURLs {
            try? FileManager.default.removeItem(at: url)
        }
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testDeleteMovesDirectoryToTrashAndReportsReclaimedBytes() async throws {
        let directory = temporaryDirectory.appending(path: "remove-me", directoryHint: .isDirectory)
        let nestedDirectory = directory.appending(path: "nested", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_096).write(to: directory.appending(path: "cache.bin"))
        try Data(repeating: 2, count: 8_192).write(to: nestedDirectory.appending(path: "artifact.bin"))

        let result = await FileManagerCleanupService().delete(urls: [directory])
        trashedURLs.append(contentsOf: result.deletedURLs)

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.deletedCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertTrue(result.deletedURLs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        XCTAssertEqual(result.deletedItems.first?.originalURL, directory)
        XCTAssertGreaterThanOrEqual(result.deletedItems.first?.bytesReclaimed ?? 0, 12_288)
        XCTAssertGreaterThanOrEqual(result.totalBytesReclaimed, 12_288)
    }
}
