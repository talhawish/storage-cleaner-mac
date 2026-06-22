import Foundation
import XCTest
@testable import StorageCleaner

final class LargeFileScannerPackageTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testKeepsInstallerPackagesEvenWhenExecutable() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let executableAPK = downloads.appending(path: "debug.apk")
        let executableIPA = downloads.appending(path: "AdHoc.ipa")
        let executableArchive = downloads.appending(path: "installer-helper.zip")

        try Data(repeating: 1, count: 24_000).write(to: executableAPK)
        try Data(repeating: 2, count: 24_000).write(to: executableIPA)
        try Data(repeating: 3, count: 24_000).write(to: executableArchive)
        for url in [executableAPK, executableIPA, executableArchive] {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: url.path
            )
        }

        let scanner = LargeFileScanner(
            roots: [downloads],
            minimumBytes: 10_000,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = result.finding?.filePaths.map(\.standardizedFileURL) ?? []

        XCTAssertEqual(Set(paths), Set([
            executableAPK.standardizedFileURL,
            executableIPA.standardizedFileURL
        ]))
        XCTAssertFalse(paths.contains(executableArchive.standardizedFileURL))
    }
}
