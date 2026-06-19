import XCTest
@testable import StorageCleaner

final class StorageFormattingTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSmallSizesUseKilobytesNotZeroMegabytes() {
        XCTAssertEqual(StorageFormatting.bytes(Int64(12_000)), "12 KB")
        XCTAssertEqual(StorageFormatting.bytes(Int64(240_000)), "240 KB")
    }

    func testSubKilobyteSizesUseBytes() {
        XCTAssertEqual(StorageFormatting.bytes(Int64(200)), "200 bytes")
        XCTAssertEqual(StorageFormatting.bytes(Int64(1)), "1 byte")
    }

    func testZeroRendersAsCleanZeroKB() {
        XCTAssertEqual(StorageFormatting.bytes(Int64(0)), "0 KB")
    }

    func testLargeSizesStillUseMegabytesAndGigabytes() {
        XCTAssertEqual(StorageFormatting.bytes(Int64(216_000_000)), "216 MB")
        XCTAssertEqual(StorageFormatting.bytes(Int64(3_400_000_000)), "3.4 GB")
    }

    func testDetailFileMetadataUsesRecursiveDirectorySize() throws {
        let directory = root.appendingPathComponent("DerivedData", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(count: 4096).write(to: directory.appendingPathComponent("Build.noindex"))

        let metadata = DetailFileMetadata.load(for: directory)

        XCTAssertTrue(metadata.exists)
        XCTAssertGreaterThan(metadata.bytes, 0)
    }

    func testDetailFileMetadataReadsSimulatorDeviceName() throws {
        let device = root.appendingPathComponent("Devices/UUID", isDirectory: true)
        try FileManager.default.createDirectory(at: device, withIntermediateDirectories: true)
        let plist: [String: String] = [
            "name": "iPhone 16 Pro",
            "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-26-0"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: device.appendingPathComponent("device.plist"))

        let metadata = DetailFileMetadata.load(for: device)

        XCTAssertEqual(metadata.displayName, "iPhone 16 Pro")
        XCTAssertEqual(metadata.parentDisplayName, "iOS 26 0")
    }
}
