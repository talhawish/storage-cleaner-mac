import XCTest
@testable import StorageCleaner

final class StorageOverviewTests: XCTestCase {
    private func finding(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        items: Int = 1,
        safety: CleanupSafety = .safe
    ) -> StorageFinding {
        StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: items,
            safety: safety,
            examples: [],
            filePaths: []
        )
    }

    func testDomainUsagesRollUpSortAndShare() {
        let usages = StorageOverview.domainUsages(in: [
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 60, items: 2),
            finding(.runtimeVersions, .appleDevelopment, bytes: 40, items: 3),
            finding(.nodeDependencies, .webDevelopment, bytes: 100, items: 5)
        ])

        XCTAssertEqual(usages.map(\.domain), [.appleDevelopment, .webDevelopment])
        let apple = usages.first { $0.domain == .appleDevelopment }
        XCTAssertEqual(apple?.bytes, 100)
        XCTAssertEqual(apple?.itemCount, 5)
        XCTAssertEqual(apple?.share ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(apple?.findings.map(\.kind), [.xcodeArtifacts, .runtimeVersions])
    }

    func testZeroByteFindingsAreDropped() {
        let usages = StorageOverview.domainUsages(in: [
            finding(.dockerArtifacts, .containers, bytes: 0),
            finding(.aiModelCaches, .artificialIntelligence, bytes: 10)
        ])

        XCTAssertEqual(usages.map(\.domain), [.artificialIntelligence])
    }

    func testEmptyFindingsProduceNoUsages() {
        XCTAssertTrue(StorageOverview.domainUsages(in: []).isEmpty)
        XCTAssertTrue(StorageOverview.tiles(in: [], maxTiles: 6).isEmpty)
    }

    func testTilesFoldTailIntoOther() {
        let findings = (0..<8).map { index in
            finding(
                StorageFindingKind.allCases[index],
                StorageDomain.allCases[index],
                bytes: Int64(100 - index * 10)
            )
        }

        let tiles = StorageOverview.tiles(in: findings, maxTiles: 4)
        XCTAssertEqual(tiles.count, 4)
        XCTAssertEqual(tiles.filter(\.isOther).count, 1)

        let other = tiles.last
        XCTAssertEqual(other?.isOther, true)
        XCTAssertEqual(other?.displayTitle, "Other")
        XCTAssertEqual(other?.id, "overview-other-rollup")
        // maxTiles 4 → top 3 (100, 90, 80) shown; Other folds the remaining five
        // (70 + 60 + 50 + 40 + 30 = 250).
        XCTAssertEqual(other?.bytes, 250)
    }

    func testTilesReturnAllWhenWithinCap() {
        let findings = [
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 30),
            finding(.nodeDependencies, .webDevelopment, bytes: 20)
        ]
        let tiles = StorageOverview.tiles(in: findings, maxTiles: 6)
        XCTAssertEqual(tiles.count, 2)
        XCTAssertFalse(tiles.contains { $0.isOther })
    }

    func testSafeAndReviewByteSplit() {
        let findings = [
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 30, safety: .safe),
            finding(.screenshots, .screenshots, bytes: 12, safety: .review),
            finding(.trash, .trash, bytes: 8, safety: .review)
        ]

        XCTAssertEqual(StorageOverview.safeBytes(in: findings), 30)
        XCTAssertEqual(StorageOverview.reviewBytes(in: findings), 20)
    }

    func testShareLabelRounds() {
        let usages = StorageOverview.domainUsages(in: [
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 1),
            finding(.nodeDependencies, .webDevelopment, bytes: 2)
        ])
        let web = usages.first { $0.domain == .webDevelopment }
        XCTAssertEqual(web?.shareLabel, "67%")
    }
}
