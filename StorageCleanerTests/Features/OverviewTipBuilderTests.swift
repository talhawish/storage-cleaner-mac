import XCTest
@testable import StorageCleaner

final class OverviewTipBuilderTests: XCTestCase {
    private func snapshot(_ findings: [StorageFinding]) -> ScanSnapshot {
        ScanSnapshot(findings: findings, scannedItemCount: findings.count, duration: .seconds(1))
    }

    private func finding(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        safety: CleanupSafety
    ) -> StorageFinding {
        StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: 1,
            safety: safety,
            examples: [],
            filePaths: []
        )
    }

    func testBiggestQuickWinPicksLargestSafeFinding() {
        let tips = OverviewTipBuilder.tips(for: snapshot([
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 50, safety: .safe),
            finding(.nodeDependencies, .webDevelopment, bytes: 90, safety: .safe),
            finding(.largeVideos, .media, bytes: 200, safety: .review) // larger but not safe
        ]))

        let win = tips.first { $0.id == "quick-win" }
        XCTAssertEqual(win?.action, .reveal(.nodeDependencies))
        XCTAssertTrue(win?.message.contains("Node.js dependencies") ?? false)
    }

    func testNoQuickWinWhenNothingSafe() {
        let tips = OverviewTipBuilder.tips(for: snapshot([
            finding(.largeVideos, .media, bytes: 200, safety: .review)
        ]))
        XCTAssertNil(tips.first { $0.id == "quick-win" })
    }

    func testSafeReviewSplitActionDependsOnSafeBytes() {
        let withSafe = OverviewTipBuilder.tips(for: snapshot([
            finding(.xcodeArtifacts, .appleDevelopment, bytes: 50, safety: .safe),
            finding(.largeVideos, .media, bytes: 20, safety: .review)
        ]))
        XCTAssertEqual(withSafe.first { $0.id == "safe-review" }?.action, .quickClean)

        let reviewOnly = OverviewTipBuilder.tips(for: snapshot([
            finding(.largeVideos, .media, bytes: 20, safety: .review)
        ]))
        XCTAssertNil(reviewOnly.first { $0.id == "safe-review" }?.action)
    }

    func testStaleTipOnlyWhenHintsPresentAndPicksLargest() {
        let base = snapshot([finding(.xcodeArtifacts, .appleDevelopment, bytes: 50, safety: .safe)])
        XCTAssertNil(OverviewTipBuilder.tips(for: base).first { $0.id == "stale" })

        let hints = [
            StaleHint(kind: .nodeDependencies, domain: .webDevelopment, bytes: 30, daysSinceModified: 120),
            StaleHint(kind: .xcodeArtifacts, domain: .appleDevelopment, bytes: 80, daysSinceModified: 200)
        ]
        let stale = OverviewTipBuilder.tips(for: base, stale: hints).first { $0.id == "stale" }
        XCTAssertEqual(stale?.action, .reveal(.xcodeArtifacts))
        XCTAssertTrue(stale?.message.contains("200+ days") ?? false)
    }

    func testEmptySnapshotProducesNoTips() {
        XCTAssertTrue(OverviewTipBuilder.tips(for: snapshot([])).isEmpty)
    }

    func testTipsCapAtThree() {
        let tips = OverviewTipBuilder.tips(
            for: snapshot([
                finding(.xcodeArtifacts, .appleDevelopment, bytes: 50, safety: .safe),
                finding(.largeVideos, .media, bytes: 20, safety: .review)
            ]),
            stale: [StaleHint(kind: .xcodeArtifacts, domain: .appleDevelopment, bytes: 50, daysSinceModified: 120)]
        )
        XCTAssertEqual(tips.count, 3)
    }
}
