import Foundation
import XCTest
@testable import StorageCleaner

final class LeftoversScannerTests: XCTestCase {
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

    func testScannerFindsLooseInstallerFiles() async throws {
        try write("Xcode.dmg")
        try write("MyApp.ipa")
        try write("tool.pkg")

        let result = await makeScanner().scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .installerLeftovers)
        XCTAssertEqual(finding.domain, .leftovers)
        XCTAssertEqual(finding.safety, .review)
        XCTAssertEqual(finding.itemCount, 3)
        XCTAssertGreaterThan(finding.bytes, 0)
    }

    func testScannerExcludesAndroidPackagesAndBuildArtifacts() async throws {
        try write("Installer.dmg")            // kept
        try write("debug.apk")               // excluded: owned by AndroidPackageScanner
        try write("release.aab")             // excluded: owned by AndroidPackageScanner
        try write("notes.txt")               // excluded: not an installer
        try write("node_modules/bundled.dmg") // excluded: dependency directory
        try write("build/output.pkg")        // excluded: build directory

        let result = await makeScanner().scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.itemCount, 1)
        XCTAssertEqual(finding.examples, ["Installer.dmg"])
    }

    func testScannerReturnsNoFindingWhenNoInstallersPresent() async throws {
        try write("readme.md")
        try write("photo.png")

        let result = await makeScanner().scan()

        XCTAssertNil(result.finding)
    }

    func testLeftoversSectionAggregatesInstallerAndAndroidKinds() {
        XCTAssertEqual(
            AppSection.leftovers.filterKinds,
            [.installerLeftovers, .androidPackages]
        )
    }

    // MARK: - Helpers

    private func makeScanner() -> LeftoversScanner {
        LeftoversScanner(roots: [temporaryDirectory], collector: FileSystemCollector())
    }

    private func write(_ relativePath: String, bytes: Int = 4_096) throws {
        let url = temporaryDirectory.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: bytes).write(to: url)
    }
}
