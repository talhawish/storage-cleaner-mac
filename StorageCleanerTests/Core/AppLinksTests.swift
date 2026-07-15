import XCTest
@testable import StorageCleaner

final class AppLinksTests: XCTestCase {
    func testTermsUsesAppleStandardEULA() {
        XCTAssertEqual(
            AppLinks.terms.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
    }

    func testPrivacyUsesPublishedHTTPSPolicy() {
        XCTAssertEqual(AppLinks.privacy.scheme, "https")
        XCTAssertEqual(AppLinks.privacy.host, "storagecleaner.horizam.com")
        XCTAssertEqual(AppLinks.privacy.path, "/privacy")
    }
}
