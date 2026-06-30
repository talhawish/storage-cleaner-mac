import XCTest
@testable import StorageCleaner

final class URLRowIdentityTests: XCTestCase {
    func testRowsGiveDuplicateURLsDistinctIDs() {
        let url = URL(filePath: "/tmp/repeated-cache")

        let rows = URLRowIdentity.rows(for: [url, url])

        XCTAssertEqual(rows.map(\.url), [url, url])
        XCTAssertEqual(rows.map(\.id), [0, 1])
        XCTAssertEqual(Set(rows.map(\.id)).count, rows.count)
    }
}
