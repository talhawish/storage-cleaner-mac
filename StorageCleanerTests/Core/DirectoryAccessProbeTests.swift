import Foundation
import XCTest
@testable import StorageCleaner

final class DirectoryAccessProbeTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Restore permissions first so the directory can be removed even after the denied-access test.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporaryDirectory.path)
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testReadableDirectoryIsAccessible() {
        XCTAssertEqual(DirectoryAccessProbe.state(of: temporaryDirectory), .accessible)
    }

    func testNonexistentPathIsMissing() {
        let missing = temporaryDirectory.appending(path: "does-not-exist", directoryHint: .isDirectory)
        XCTAssertEqual(DirectoryAccessProbe.state(of: missing), .missing)
    }

    func testFilePathIsMissing() throws {
        let file = temporaryDirectory.appending(path: "note.txt")
        try Data("hi".utf8).write(to: file)
        XCTAssertEqual(DirectoryAccessProbe.state(of: file), .missing)
    }

    func testUnreadableDirectoryIsDenied() throws {
        // root bypasses POSIX permission checks, so the denial signal cannot be reproduced there.
        try XCTSkipIf(geteuid() == 0, "Permission denial cannot be simulated when running as root.")

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: temporaryDirectory.path)
        XCTAssertEqual(DirectoryAccessProbe.state(of: temporaryDirectory), .denied)
    }
}
