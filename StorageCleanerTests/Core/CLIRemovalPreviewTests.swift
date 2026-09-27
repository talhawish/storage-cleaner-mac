import Foundation
import XCTest
@testable import StorageCleaner

final class CLIRemovalPreviewTests: XCTestCase {
    func testStandaloneExecutablePreviewPromisesOnlySelectedFile() {
        let url = URL(fileURLWithPath: "/Users/me/.opencode/bin/opencode")
        let preview = CLIRemovalPreview.forURL(url)

        XCTAssertEqual(preview.method, "Move file to Trash")
        XCTAssertTrue(preview.detail.contains("Only this file"))
        XCTAssertTrue(preview.canRemove)
    }

    func testDirectoryPreviewExplainsNestedDataIsIncluded() {
        let url = URL(fileURLWithPath: "/Users/me/.pyenv/versions/3.11.4", isDirectory: true)
        let preview = CLIRemovalPreview.forURL(url)

        XCTAssertEqual(preview.method, "Move folder to Trash")
        XCTAssertTrue(preview.detail.contains("settings or saved data"))
    }

    func testHomebrewPreviewDescribesManagerAndPreservedDataPolicy() {
        let url = URL(fileURLWithPath: "/opt/homebrew/Cellar/git", isDirectory: true)
        let preview = CLIRemovalPreview.forURL(url)

        XCTAssertEqual(preview.method, "Uninstall Homebrew formula")
        XCTAssertTrue(preview.detail.contains("--zap"))
    }

    func testNodeGlobalPreviewNamesMatchingManager() {
        let url = URL(fileURLWithPath: "/Users/me/.bun/install/global/node_modules/opencode-ai", isDirectory: true)
        let preview = CLIRemovalPreview.forURL(url)

        XCTAssertEqual(preview.method, "Uninstall with bun")
        XCTAssertTrue(preview.detail.contains("must be available"))
    }

    func testSystemJDKPreviewBlocksAutomaticRemoval() {
        let url = URL(fileURLWithPath: "/Library/Java/JavaVirtualMachines/temurin-21.jdk", isDirectory: true)
        let preview = CLIRemovalPreview.forURL(url)

        XCTAssertFalse(preview.canRemove)
        XCTAssertEqual(preview.method, "Manual removal required")
    }
}
