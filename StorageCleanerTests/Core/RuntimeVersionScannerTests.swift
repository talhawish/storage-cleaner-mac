import Foundation
import XCTest
@testable import StorageCleaner

final class RuntimeVersionScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeDir(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func environment() -> RuntimeVersionCatalog.Environment {
        RuntimeVersionCatalog.Environment(
            home: root.appendingPathComponent("home", isDirectory: true),
            homebrewCellars: [],
            jvmDirectory: root.appendingPathComponent("no-jvm", isDirectory: true)
        )
    }

    func testFindingCoversOnlyTheRemovableOlderVersions() async throws {
        let old = try makeDir("home/.nvm/versions/node/v18.20.4")
        _ = try makeDir("home/.nvm/versions/node/v20.11.1")
        try Data(count: 8192).write(to: old.appendingPathComponent("payload.bin"))

        let result = await RuntimeVersionScanner(environment: environment()).scan()
        let finding = try XCTUnwrap(result.finding)

        XCTAssertEqual(finding.kind, .runtimeVersions)
        XCTAssertEqual(finding.domain, .otherCaches)
        XCTAssertEqual(finding.safety, .review)
        XCTAssertEqual(finding.itemCount, 1, "only the older version is removable")
        XCTAssertEqual(finding.filePaths.first?.lastPathComponent, "v18.20.4")
        XCTAssertGreaterThan(finding.bytes, 0)
    }

    func testNoFindingWhenEveryRuntimeHasASingleVersion() async throws {
        _ = try makeDir("home/.pyenv/versions/3.12.1")

        let result = await RuntimeVersionScanner(environment: environment()).scan()
        XCTAssertNil(result.finding)
    }
}
