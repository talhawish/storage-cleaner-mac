import XCTest
@testable import StorageCleaner

final class VersionKeyTests: XCTestCase {
    func testParsesLeadingNumericComponentsAfterOptionalV() {
        XCTAssertEqual(VersionKey.parse("v18.20.4").numbers, [18, 20, 4])
        XCTAssertEqual(VersionKey.parse("8.1.29").numbers, [8, 1, 29])
        XCTAssertEqual(VersionKey.parse("3.12.1").numbers, [3, 12, 1])
    }

    func testStopsAtTheFirstNonNumericToken() {
        // Rust toolchains carry an arch suffix that must not pollute the version.
        XCTAssertEqual(VersionKey.parse("1.75.0-aarch64-apple-darwin").numbers, [1, 75, 0])
    }

    func testNameDashVersionStillExtractsVersion() {
        // JDK bundle names like `temurin-17.0.2` and `ruby-3.2.2`.
        XCTAssertEqual(VersionKey.parse("temurin-17.0.2").numbers, [17, 0, 2])
        XCTAssertEqual(VersionKey.parse("ruby-3.2.2").numbers, [3, 2, 2])
    }

    func testChannelNamesHaveNoNumbersAndAreNotPreRelease() {
        let stable = VersionKey.parse("stable-aarch64-apple-darwin")
        XCTAssertEqual(stable.numbers, [])
        XCTAssertFalse(stable.isPreRelease, "`rc` inside `aarch64` must not flag a pre-release")
    }

    func testDetectsPreReleaseTokens() {
        XCTAssertTrue(VersionKey.parse("nightly-2025-01-01-aarch64").isPreRelease)
        XCTAssertTrue(VersionKey.parse("1.75.0-beta").isPreRelease)
        XCTAssertTrue(VersionKey.parse("3.13.0rc1").isPreRelease)
        XCTAssertFalse(VersionKey.parse("1.75.0").isPreRelease)
    }

    func testNumericOrderingIsByComponentNotLexical() {
        XCTAssertTrue(VersionKey.parse("18.20.4") > VersionKey.parse("9.99.99"))
        XCTAssertTrue(VersionKey.parse("1.75.0") > VersionKey.parse("1.74.10"))
        XCTAssertTrue(VersionKey.parse("3.12.1") > VersionKey.parse("3.12.0"))
    }

    func testReleaseOutranksPreReleaseAtSameVersion() {
        XCTAssertTrue(VersionKey.parse("1.75.0") > VersionKey.parse("1.75.0-nightly"))
    }

    func testNewestIsTheMaximum() {
        let labels = ["16.10.0", "18.20.4", "20.11.1", "14.0.0"]
        let newest = labels.max { VersionKey.parse($0) < VersionKey.parse($1) }
        XCTAssertEqual(newest, "20.11.1")
    }
}
