import Foundation
import XCTest
@testable import StorageCleaner

final class StorageInventoryPresentationTests: XCTestCase {
    func testRowsAreLargestFirstAndOpenOnlyTheChosenPath() throws {
        let small = URL(fileURLWithPath: "/example/small.gguf")
        let large = URL(fileURLWithPath: "/example/large.gguf")
        let finding = try XCTUnwrap(CandidateFindingBuilder().makeFinding(
            kind: .localAIModels,
            domain: .artificialIntelligence,
            candidates: [FileCandidate(url: small, bytes: 100), FileCandidate(url: large, bytes: 200)],
            safety: .review
        ))
        let inventory = StorageInventoryPresentation(findings: [finding])
        XCTAssertEqual(inventory.items.map(\.url), [large, small])
        XCTAssertTrue(inventory.reviewMessage.contains("not known to be unused"))
        let detail = try XCTUnwrap(inventory.items.first?.detailFinding)
        XCTAssertEqual(detail.filePaths, [large])
        XCTAssertEqual(detail.bytes, 200)
        XCTAssertEqual(detail.itemCount, 1)
        XCTAssertEqual(detail.pathBytes, [large: 200])
        XCTAssertEqual(detail.safety, .review)
    }

    func testSinglePathWithoutDetailedSizesUsesFindingTotal() {
        let url = URL(fileURLWithPath: "/example/model-store")
        let finding = StorageFinding(
            kind: .aiModelCaches,
            domain: .artificialIntelligence,
            bytes: 900_000,
            itemCount: 1,
            safety: .review,
            examples: [],
            filePaths: [url]
        )
        let inventory = StorageInventoryPresentation(findings: [finding])
        XCTAssertEqual(inventory.items.first?.bytes, 900_000)
        XCTAssertEqual(inventory.items.first?.detailFinding.bytes, 900_000)
    }

    func testEqualSizesHaveStableOrdering() throws {
        let urls = [URL(fileURLWithPath: "/example/b"), URL(fileURLWithPath: "/example/a")]
        let finding = try XCTUnwrap(CandidateFindingBuilder().makeFinding(
            kind: .largeFolders,
            domain: .otherCaches,
            candidates: urls.map { FileCandidate(url: $0, bytes: 100) },
            safety: .review
        ))
        let inventory = StorageInventoryPresentation(findings: [finding])
        XCTAssertEqual(inventory.items.map(\.url.lastPathComponent), ["a", "b"])
        XCTAssertEqual(Set(inventory.items.map(\.id)).count, 2)
    }
}
