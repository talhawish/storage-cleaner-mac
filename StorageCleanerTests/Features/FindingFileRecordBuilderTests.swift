import XCTest
@testable import StorageCleaner

final class FindingFileRecordBuilderTests: XCTestCase {
    func testRecordsUseInjectedMetadataOncePerPath() {
        let first = URL(filePath: "/Users/test/Downloads/installer.dmg")
        let second = URL(filePath: "/Users/test/Downloads/app.apk")
        var measuredURLs: [URL] = []

        let records = FindingFileRecordBuilder.records(from: [
            StorageFinding(
                kind: .installerLeftovers,
                domain: .leftovers,
                bytes: 300,
                itemCount: 2,
                safety: .review,
                examples: [],
                filePaths: [first, second]
            )
        ]) { url, _ in
            measuredURLs.append(url)
            return FindingFileRecordMetadata(
                exists: true,
                bytes: url == first ? 100 : 200,
                modifiedAt: Date(timeIntervalSince1970: url == first ? 1 : 2)
            )
        }

        XCTAssertEqual(measuredURLs, [first, second])
        XCTAssertEqual(records.map(\.url), [first, second])
        XCTAssertEqual(records.map(\.bytes), [100, 200])
        XCTAssertEqual(records.map(\.kind), [.installerLeftovers, .installerLeftovers])
        XCTAssertEqual(records.map(\.domain), [.leftovers, .leftovers])
        XCTAssertTrue(records.allSatisfy(\.exists))
    }

    func testRecordIdentityIncludesKindAndURL() {
        let url = URL(filePath: "/Users/test/Downloads/package.zip")

        let records = FindingFileRecordBuilder.records(from: [
            StorageFinding(
                kind: .largeFiles,
                domain: .otherCaches,
                bytes: 100,
                itemCount: 1,
                safety: .review,
                examples: [],
                filePaths: [url]
            ),
            StorageFinding(
                kind: .installerLeftovers,
                domain: .leftovers,
                bytes: 100,
                itemCount: 1,
                safety: .review,
                examples: [],
                filePaths: [url]
            )
        ]) { _, _ in
            FindingFileRecordMetadata(exists: true, bytes: 100, modifiedAt: nil)
        }

        XCTAssertEqual(records.count, 2)
        XCTAssertNotEqual(records[0].id, records[1].id)
    }

    func testPathBytesFlowsThroughAsPrecomputedBytes() {
        let first = URL(filePath: "/Users/test/Downloads/installer.dmg")
        let second = URL(filePath: "/Users/test/Downloads/app.apk")

        let records = FindingFileRecordBuilder.records(from: [
            StorageFinding(
                kind: .installerLeftovers,
                domain: .leftovers,
                bytes: 300,
                itemCount: 2,
                safety: .review,
                examples: [],
                filePaths: [first, second],
                pathBytes: [first: 100, second: 200]
            )
        ]) { _, precomputed in
            FindingFileRecordMetadata(
                exists: true,
                bytes: precomputed ?? 0,
                modifiedAt: nil
            )
        }

        XCTAssertEqual(
            records.map(\.bytes),
            [100, 200],
            "pathBytes must flow through as precomputedBytes so rows show correct sizes"
        )
    }

    func testTotalSelectedBytesDoesNotRemeasureOrDoubleCountDuplicateURLs() {
        let url = URL(filePath: "/Users/test/Downloads/package.zip")
        let otherURL = URL(filePath: "/Users/test/Downloads/other.zip")
        let records = [
            FindingFileRecord(
                url: url,
                kind: .largeFiles,
                domain: .otherCaches,
                bytes: 120,
                exists: true,
                modifiedAt: nil
            ),
            FindingFileRecord(
                url: url,
                kind: .installerLeftovers,
                domain: .leftovers,
                bytes: 120,
                exists: true,
                modifiedAt: nil
            ),
            FindingFileRecord(
                url: otherURL,
                kind: .installerLeftovers,
                domain: .leftovers,
                bytes: 80,
                exists: true,
                modifiedAt: nil
            )
        ]

        XCTAssertEqual(
            FindingFileRecordBuilder.totalSelectedBytes(selectedURLs: [url, otherURL], records: records),
            200
        )
    }
}
