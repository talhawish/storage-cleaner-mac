import Foundation
import XCTest
@testable import StorageCleaner

final class SystemJunkSymlinkSafetyTests: XCTestCase {
    func testOrphanedAppSupportSkipsSymbolicLinks() throws {
        let temporaryLibrary = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: temporaryLibrary) }

        let root = temporaryLibrary.appending(path: "Application Support")
        let target = root.appending(path: "TargetData", directoryHint: .isDirectory)
        let link = root.appending(path: "LinkedData", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let resolver = OrphanDirectoryResolver(
            root: root,
            catalog: InstalledAppCatalog(searchRoots: []),
            limit: 200
        )

        XCTAssertFalse(resolver.resolveOrphans().contains(link))
    }
}
