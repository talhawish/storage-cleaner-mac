import XCTest
@testable import StorageCleaner

final class FileCleanupRequestTests: XCTestCase {
    func testEmptySelectionDoesNotCreateRequest() {
        XCTAssertNil(FileCleanupRequest(urls: [URL](), totalBytes: 0))
    }

    func testRequestSnapshotsSelectionAndSize() throws {
        let first = URL(filePath: "/Users/test/Downloads/archive.dmg")
        let second = URL(filePath: "/Users/test/Desktop/video.mov")
        var selection: Set<URL> = [second, first]

        let request = try XCTUnwrap(FileCleanupRequest(urls: selection, totalBytes: 750))
        selection.removeAll()

        XCTAssertEqual(request.urls, [second, first].sorted(by: pathAscending))
        XCTAssertEqual(request.totalBytes, 750)
    }

    func testRequestDeduplicatesURLs() throws {
        let url = URL(filePath: "/Users/test/Downloads/archive.dmg")

        let request = try XCTUnwrap(FileCleanupRequest(urls: [url, url], totalBytes: 500))

        XCTAssertEqual(request.urls, [url])
    }

    private func pathAscending(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
    }
}
