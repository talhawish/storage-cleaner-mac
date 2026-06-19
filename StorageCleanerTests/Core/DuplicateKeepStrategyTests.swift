import Foundation
import XCTest
@testable import StorageCleaner

final class DuplicateKeepStrategyTests: XCTestCase {
    private func file(_ path: String, modifiedAt: Date? = nil) -> DuplicateFile {
        DuplicateFile(url: URL(fileURLWithPath: path), bytes: 10_000, modifiedAt: modifiedAt)
    }

    func testPrefersPermanentLocationOverDownloads() {
        let files = [
            file("/Users/me/Downloads/photo.png"),
            file("/Users/me/Pictures/photo.png")
        ]

        let keep = DuplicateKeepStrategy.bestToKeep(from: files)

        XCTAssertEqual(keep.url.path, "/Users/me/Pictures/photo.png")
    }

    func testPenalizesCopyMarkers() {
        let files = [
            file("/Users/me/Pictures/photo copy.png"),
            file("/Users/me/Pictures/photo.png")
        ]

        let keep = DuplicateKeepStrategy.bestToKeep(from: files)

        XCTAssertEqual(keep.url.lastPathComponent, "photo.png")
    }

    func testPrefersOlderCopyWhenOtherwiseEqual() {
        let older = Date(timeIntervalSinceReferenceDate: 0)
        let newer = Date(timeIntervalSinceReferenceDate: 400 * 86_400)
        let files = [
            file("/Users/me/Pictures/a.png", modifiedAt: newer),
            file("/Users/me/Pictures/b.png", modifiedAt: older)
        ]

        let keep = DuplicateKeepStrategy.bestToKeep(from: files)

        XCTAssertEqual(keep.modifiedAt, older)
    }

    func testIsDeterministicForEquivalentCandidates() {
        let files = [
            file("/Users/me/Pictures/b.png"),
            file("/Users/me/Pictures/a.png")
        ]

        let first = DuplicateKeepStrategy.bestToKeep(from: files)
        let second = DuplicateKeepStrategy.bestToKeep(from: files.reversed())

        XCTAssertEqual(first.url, second.url)
        XCTAssertEqual(first.url.lastPathComponent, "a.png")
    }
}
