import Foundation
import XCTest
@testable import StorageCleaner

final class DuplicateGrouperTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ name: String, data: Data) throws -> FileCandidate {
        let url = root.appending(path: name)
        try data.write(to: url)
        return FileCandidate(url: url, bytes: Int64(data.count))
    }

    func testIdenticalFilesGroupTogether() async throws {
        let payload = Data(repeating: 7, count: 10_000)
        let first = try write("copy-a.jpg", data: payload)
        let second = try write("copy-b.jpg", data: payload)
        let different = try write("other.jpg", data: Data(repeating: 9, count: 10_000))

        let groups = await DuplicateGrouper.groups(
            from: [first, second, different],
            minimumBytes: 1
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(
            Set(groups[0].files.map(\.url.lastPathComponent)),
            ["copy-a.jpg", "copy-b.jpg"]
        )
    }

    /// The critical correctness test for the 64 KiB prefilter: same-size files
    /// with an identical first 64 KiB but different tails are NOT duplicates
    /// and must still be split by the full-content hash.
    func testSamePrefixDifferentTailIsNotADuplicate() async throws {
        var contentA = Data(repeating: 1, count: DuplicateGrouper.prefixByteCount + 4_096)
        var contentB = contentA
        contentA[contentA.count - 1] = 0xAA
        contentB[contentB.count - 1] = 0xBB

        let first = try write("tail-a.mp4", data: contentA)
        let second = try write("tail-b.mp4", data: contentB)

        let groups = await DuplicateGrouper.groups(from: [first, second], minimumBytes: 1)

        XCTAssertTrue(groups.isEmpty, "files differing beyond the prefix must not group")
    }

    func testLargeIdenticalFilesStillGroupThroughFullHash() async throws {
        let payload = Data((0..<(DuplicateGrouper.prefixByteCount + 50_000)).map { UInt8($0 % 251) })
        let first = try write("big-a.mp4", data: payload)
        let second = try write("big-b.mp4", data: payload)

        let groups = await DuplicateGrouper.groups(from: [first, second], minimumBytes: 1)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].files.count, 2)
    }

    func testMinimumBytesFloorExcludesSmallFiles() async throws {
        let payload = Data(repeating: 3, count: 512)
        let first = try write("small-a.png", data: payload)
        let second = try write("small-b.png", data: payload)

        let groups = await DuplicateGrouper.groups(from: [first, second], minimumBytes: 1_024)

        XCTAssertTrue(groups.isEmpty)
    }

    func testGroupsSortLargestReclaimFirstDeterministically() async throws {
        let bigPayload = Data(repeating: 4, count: 40_000)
        let smallPayload = Data(repeating: 5, count: 4_000)
        let candidates = [
            try write("big-1.jpg", data: bigPayload),
            try write("big-2.jpg", data: bigPayload),
            try write("small-1.jpg", data: smallPayload),
            try write("small-2.jpg", data: smallPayload)
        ]

        let groups = await DuplicateGrouper.groups(from: candidates, minimumBytes: 1)

        XCTAssertEqual(groups.count, 2)
        XCTAssertGreaterThan(groups[0].reclaimableBytes, groups[1].reclaimableBytes)
    }
}
