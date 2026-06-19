import Foundation
import XCTest
@testable import StorageCleaner

final class DuplicateMediaScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testReportsLikelyDuplicatesOnly() async throws {
        let pictures = temporaryDirectory.appending(path: "Pictures", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        let payload = Data(repeating: 2, count: 20_000)

        try payload.write(to: pictures.appending(path: "launch.png"))
        try payload.write(to: pictures.appending(path: "renamed-export.png"))
        try Data(repeating: 3, count: 20_000).write(to: pictures.appending(path: "unique.png"))

        let scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: [pictures],
            extensions: ["png"],
            minimumBytes: 128,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.kind, .duplicatePhotos)
        XCTAssertEqual(result.finding?.itemCount, 1)
        XCTAssertEqual(result.finding?.bytes, 20_480)
        XCTAssertEqual(result.inspectedItemCount, 3)

        // The grouping is preserved on the finding: one group with both identical copies.
        let groups = try XCTUnwrap(result.finding?.duplicateGroups)
        XCTAssertEqual(groups.count, 1)
        let group = try XCTUnwrap(groups.first)
        XCTAssertEqual(group.files.count, 2)
        XCTAssertEqual(group.removableCount, 1)
        XCTAssertEqual(group.reclaimableBytes, 20_480)
        XCTAssertTrue(group.files.map(\.url).contains(group.keepURL))
        XCTAssertEqual(group.removableURLs.count, 1)
    }

    func testGroupsThreeCopiesIntoOneGroup() async throws {
        let pictures = temporaryDirectory.appending(path: "Pictures", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)
        let payload = Data(repeating: 9, count: 30_000)

        try payload.write(to: pictures.appending(path: "original.png"))
        try payload.write(to: pictures.appending(path: "original copy.png"))
        try payload.write(to: pictures.appending(path: "original copy 2.png"))

        let scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: [pictures],
            extensions: ["png"],
            minimumBytes: 128,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        let group = try XCTUnwrap(result.finding?.duplicateGroups.first)
        XCTAssertEqual(group.files.count, 3)
        XCTAssertEqual(group.removableCount, 2)
        // The copy without a "copy" marker is the recommended keep.
        XCTAssertEqual(group.keepURL.lastPathComponent, "original.png")
        XCTAssertEqual(result.finding?.itemCount, 2)
    }

    func testDoesNotReportSameSizeDifferentContent() async throws {
        let pictures = temporaryDirectory.appending(path: "Pictures", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: pictures, withIntermediateDirectories: true)

        try Data(repeating: 2, count: 20_000).write(to: pictures.appending(path: "one.png"))
        try Data(repeating: 3, count: 20_000).write(to: pictures.appending(path: "two.png"))

        let scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: [pictures],
            extensions: ["png"],
            minimumBytes: 128,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertNil(result.finding)
        XCTAssertEqual(result.inspectedItemCount, 2)
    }
}
