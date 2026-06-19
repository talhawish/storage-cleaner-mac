import Foundation
import XCTest
@testable import StorageCleaner

final class DuplicateSelectionStateTests: XCTestCase {
    private func makeGroup() -> DuplicateGroup {
        let keep = URL(fileURLWithPath: "/Users/me/Pictures/keep.png")
        let dupeA = URL(fileURLWithPath: "/Users/me/Downloads/dupeA.png")
        let dupeB = URL(fileURLWithPath: "/Users/me/Desktop/dupeB.png")
        let files = [keep, dupeA, dupeB].map { DuplicateFile(url: $0, bytes: 1_000, modifiedAt: nil) }
        return DuplicateGroup(contentHash: "hash", files: files, keepURL: keep)
    }

    func testDefaultsToRemovingEveryNonKeptCopy() {
        let group = makeGroup()
        let state = DuplicateSelectionState()

        XCTAssertEqual(state.removalURLs(in: group).count, 2)
        XCTAssertFalse(state.isMarkedForRemoval(group.keepURL, in: group))
        XCTAssertEqual(state.removalBytes(in: [group]), 2_000)
    }

    func testTogglingSparesAndRestoresACopy() {
        let group = makeGroup()
        var state = DuplicateSelectionState()
        let target = group.removableURLs[0]

        state.toggleRemoval(target, in: group)
        XCTAssertFalse(state.isMarkedForRemoval(target, in: group))
        XCTAssertEqual(state.removalURLs(in: group).count, 1)

        state.toggleRemoval(target, in: group)
        XCTAssertTrue(state.isMarkedForRemoval(target, in: group))
        XCTAssertEqual(state.removalURLs(in: group).count, 2)
    }

    func testKeptCopyCannotBeMarkedForRemoval() {
        let group = makeGroup()
        var state = DuplicateSelectionState()

        state.toggleRemoval(group.keepURL, in: group)

        XCTAssertFalse(state.isMarkedForRemoval(group.keepURL, in: group))
        XCTAssertEqual(state.removalURLs(in: group).count, 2)
    }

    func testReElectingKeepProtectsNewCopyAndExposesOldOne() {
        let group = makeGroup()
        var state = DuplicateSelectionState()
        let newKeep = group.removableURLs[0]

        state.setKeep(newKeep, in: group)

        XCTAssertTrue(state.isKept(newKeep, in: group))
        XCTAssertFalse(state.isMarkedForRemoval(newKeep, in: group))
        // The previously recommended copy is now removable.
        XCTAssertTrue(state.isMarkedForRemoval(group.keepURL, in: group))
        XCTAssertEqual(state.removalURLs(in: group).count, 2)
    }

    func testClearAndSelectAllForGroup() {
        let group = makeGroup()
        var state = DuplicateSelectionState()

        state.clearSelection(in: group)
        XCTAssertEqual(state.removalURLs(in: group).count, 0)

        state.selectAllRemovable(in: group)
        XCTAssertEqual(state.removalURLs(in: group).count, 2)
    }

    func testResetRestoresRecommendedDefaults() {
        let group = makeGroup()
        var state = DuplicateSelectionState()
        state.setKeep(group.removableURLs[0], in: group)
        state.clearSelection(in: group)

        state.reset()

        XCTAssertTrue(state.isKept(group.keepURL, in: group))
        XCTAssertEqual(state.removalURLs(in: group).count, 2)
    }
}
