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

    func testDeleteDirectoryCountsHiddenFilesInReclaimedBytes() async throws {
        let directory = temporaryDirectory.appending(path: "hidden-cache", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_096).write(to: directory.appending(path: ".cache"))
        try Data(repeating: 2, count: 4_096).write(to: directory.appending(path: "visible-cache"))

        let result = await FileManagerCleanupService().delete(urls: [directory])
        trashedURLs.append(contentsOf: result.deletedURLs)

        XCTAssertTrue(result.succeeded)
        XCTAssertGreaterThanOrEqual(result.deletedItems.first?.bytesReclaimed ?? 0, 8_192)
        XCTAssertGreaterThanOrEqual(result.totalBytesReclaimed, 8_192)
    }

    func testDeletePermanentlyRemovesItemAlreadyInTrash() async throws {
        let file = temporaryDirectory.appending(path: "trash-me.bin")
        try Data(repeating: 3, count: 4_096).write(to: file)

        var trashURL: NSURL?
        try FileManager.default.trashItem(at: file, resultingItemURL: &trashURL)
        guard let trashed = trashURL as? URL else {
            return XCTFail("trashItem returned nil")
        }
        trashedURLs.append(trashed)

        let result = await FileManagerCleanupService().delete(urls: [trashed])

        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertEqual(result.deletedItems.count, 1)
        XCTAssertEqual(result.deletedItems.first?.originalURL, trashed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: trashed.path))
        XCTAssertGreaterThanOrEqual(result.totalBytesReclaimed, 4_096)
    }
}
