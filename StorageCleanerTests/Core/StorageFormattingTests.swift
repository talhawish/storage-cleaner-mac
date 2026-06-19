import XCTest
@testable import StorageCleaner

final class StorageFormattingTests: XCTestCase {
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
}
