import Foundation
import XCTest
@testable import StorageCleaner

final class IosDeviceSupportScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makePack(
        under rootName: String,
        deviceName: String,
        bytes: Int
    ) throws -> URL {
        let dir = root
            .appendingPathComponent(rootName, isDirectory: true)
            .appendingPathComponent(deviceName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: dir.appendingPathComponent("Symbols.dSYM"))
        return dir
    }

    func testFindsAllPlatformsAndSumsBytes() async throws {
        // File sizes are large enough to dwarf filesystem block alignment, so the test can
        // assert exact byte counts instead of block-aligned approximations.
        let ios = try makePack(under: "iOS DeviceSupport", deviceName: "iPhone15,3 26.5 (23F77)", bytes: 65_536)
        _ = try makePack(under: "iOS DeviceSupport", deviceName: "iPhone11,6 18.7.7 (22H340)", bytes: 32_768)
        _ = try makePack(under: "tvOS DeviceSupport", deviceName: "AppleTV14,1 18.4 (22L123)", bytes: 16_384)
        _ = try makePack(under: "watchOS DeviceSupport", deviceName: "Watch7,2 11.1 (22R58220E)", bytes: 8_192)

        let scanner = IosDeviceSupportScanner(
            roots: [
                root.appendingPathComponent("iOS DeviceSupport"),
                root.appendingPathComponent("tvOS DeviceSupport"),
                root.appendingPathComponent("watchOS DeviceSupport")
            ]
        )

        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .iosDeviceSupport)
        XCTAssertEqual(finding.domain, .appleDevelopment)
        XCTAssertEqual(finding.safety, .safe)
        XCTAssertEqual(finding.itemCount, 4)
        XCTAssertEqual(finding.bytes, 65_536 + 32_768 + 16_384 + 8_192)
        XCTAssertEqual(result.inspectedItemCount, 4)
        XCTAssertTrue(finding.filePaths.map { $0.resolvingSymlinksInPath() }
            .contains(ios.resolvingSymlinksInPath()))
        XCTAssertTrue(result.message.contains("4 Device Support packs"))
    }

    func testReturnsNoFindingWhenNoPacksArePresent() async throws {
        // Empty roots directory.
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("iOS DeviceSupport"),
            withIntermediateDirectories: true
        )

        let scanner = IosDeviceSupportScanner(roots: [root.appendingPathComponent("iOS DeviceSupport")])
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
        XCTAssertEqual(result.inspectedItemCount, 0)
        XCTAssertTrue(result.message.contains("No Device Support packs"))
    }

    func testSkipsNonExistentRoots() async throws {
        let ios = try makePack(under: "iOS DeviceSupport", deviceName: "iPhone15,3 26.5 (23F77)", bytes: 65_536)
        let scanner = IosDeviceSupportScanner(roots: [
            root.appendingPathComponent("iOS DeviceSupport"),
            root.appendingPathComponent("tvOS DeviceSupport"),
            root.appendingPathComponent("watchOS DeviceSupport"),
            root.appendingPathComponent("visionOS DeviceSupport")
        ])

        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.itemCount, 1)
        XCTAssertEqual(finding.bytes, 65_536)
        XCTAssertTrue(finding.filePaths.map { $0.resolvingSymlinksInPath() }
            .contains(ios.resolvingSymlinksInPath()))
    }
}
