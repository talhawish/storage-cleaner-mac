import XCTest
@testable import StorageCleaner

final class DeveloperDomainsTests: XCTestCase {
    private func finding(_ kind: StorageFindingKind, _ domain: StorageDomain, bytes: Int64 = 1_000) -> StorageFinding {
        StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: 1,
            safety: .review,
            examples: [],
            filePaths: []
        )
    }

    func testDetectedDomainsAreOrderedAndDeduplicated() {
        let findings = [
            finding(.pythonDependencies, .otherCaches),
            finding(.nodeDependencies, .webDevelopment),
            finding(.xcodeArtifacts, .appleDevelopment),
            finding(.rustDependencies, .otherCaches) // same domain as python → deduped
        ]

        XCTAssertEqual(
            DeveloperDomains.detected(in: findings),
            [.appleDevelopment, .webDevelopment, .otherCaches]
        )
    }

    func testEmptyAndZeroByteFindingsAreExcluded() {
        let findings = [
            finding(.dockerArtifacts, .containers, bytes: 0), // zero bytes → ignored
            finding(.aiModelCaches, .artificialIntelligence)
        ]

        XCTAssertEqual(DeveloperDomains.detected(in: findings), [.artificialIntelligence])
    }

    func testNonDeveloperAndCLIToolingDomainsAreNotSurfaced() {
        let findings = [
            finding(.screenshots, .screenshots),
            finding(.trash, .trash),
            finding(.cliApps, .cliTooling) // CLI Tooling has its own section, not a dynamic row
        ]

        XCTAssertTrue(DeveloperDomains.detected(in: findings).isEmpty)
    }

    func testNoFindingsYieldsNoDomains() {
        XCTAssertTrue(DeveloperDomains.detected(in: []).isEmpty)
    }
}
