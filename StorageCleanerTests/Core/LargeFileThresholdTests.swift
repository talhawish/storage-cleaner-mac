import XCTest
@testable import StorageCleaner

final class LargeFileThresholdTests: XCTestCase {
    func testRawValuesAreMegabytes() {
        XCTAssertEqual(LargeFileThreshold.tenMB.megabytes, 10)
        XCTAssertEqual(LargeFileThreshold.oneGB.megabytes, 1000)
        XCTAssertEqual(LargeFileThreshold.tenMB.rawValue, LargeFileThreshold.tenMB.megabytes)
    }

    func testBytesConvertFromMegabytes() {
        XCTAssertEqual(LargeFileThreshold.tenMB.bytes, 10_000_000)
        XCTAssertEqual(LargeFileThreshold.hundredMB.bytes, 100_000_000)
        XCTAssertEqual(LargeFileThreshold.fiveGB.bytes, 5_000_000_000)
    }

    func testLabelMatchesFormattedBytes() {
        for threshold in LargeFileThreshold.allCases {
            XCTAssertEqual(threshold.label, StorageFormatting.bytes(threshold.bytes))
        }
    }

    func testCollectionFloorIsSmallestOption() {
        XCTAssertEqual(LargeFileThreshold.collectionFloor, .tenMB)
        XCTAssertEqual(
            LargeFileThreshold.collectionFloor.rawValue,
            LargeFileThreshold.allCases.map(\.rawValue).min()
        )
    }

    func testDefaultMegabytesIsHundred() {
        XCTAssertEqual(LargeFileThreshold.defaultMegabytes, 100)
    }
}
