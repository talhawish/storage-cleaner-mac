import Foundation
import XCTest
@testable import StorageCleaner

final class DetailDirectoryChildrenTests: XCTestCase {
    func testIncludesHiddenItemsWhenReviewingUnclassifiedStorage() throws {
        let root = try temporaryDirectory()
        try Data().write(to: root.appending(path: ".private-model.gguf"))
        try Data().write(to: root.appending(path: "visible.txt"))

        let level = try XCTUnwrap(
            DetailDirectoryChildren.level(for: root, includingHiddenFiles: true)
        )

        XCTAssertEqual(Set(level.urls.map(\.lastPathComponent)), [".private-model.gguf", "visible.txt"])
    }

    func testContinuesHidingHiddenItemsForOtherCategories() throws {
        let root = try temporaryDirectory()
        try Data().write(to: root.appending(path: ".private.txt"))
        try Data().write(to: root.appending(path: "visible.txt"))

        let level = try XCTUnwrap(DetailDirectoryChildren.level(for: root))

        XCTAssertEqual(level.urls.map(\.lastPathComponent), ["visible.txt"])
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
