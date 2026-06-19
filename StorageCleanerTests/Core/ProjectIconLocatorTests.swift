import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectIconLocatorTests: XCTestCase {
    private func score(_ name: String, in parent: String) -> Int {
        ProjectIconLocator.score(fileName: name, parentDirectory: parent)
    }

    func testXcodeAppIconSetScoresHighest() {
        XCTAssertEqual(score("AppIcon-1024.png", in: "AppIcon.appiconset"), 100)
        XCTAssertEqual(score("icon-20@2x.png", in: "AppIcon.appiconset"), 100)
        // Even a plainly named file inside the set is the app icon.
        XCTAssertEqual(score("img.png", in: "AppIcon.appiconset"), 100)
    }

    func testAndroidLauncherIconScoresAboveOtherMipmapImages() {
        let launcher = score("ic_launcher.png", in: "mipmap-xxxhdpi")
        let round = score("ic_launcher_round.png", in: "mipmap-hdpi")
        let other = score("splash.png", in: "mipmap-hdpi")
        XCTAssertEqual(launcher, 95)
        XCTAssertEqual(round, 95)
        XCTAssertEqual(other, 80)
        XCTAssertGreaterThan(launcher, other)
    }

    func testGenericNamePatternsAreRanked() {
        XCTAssertEqual(score("logo.png", in: "assets"), 70)
        XCTAssertEqual(score("icon.png", in: "src"), 68)
        XCTAssertEqual(score("apple-touch-icon.png", in: "public"), 62)
        XCTAssertEqual(score("Icon-192.png", in: "icons"), 50)
        XCTAssertEqual(score("favicon.ico", in: "public"), 55)
        XCTAssertEqual(score("company-logo.png", in: "img"), 40)
    }

    func testNonImageAndUnrelatedFilesScoreZero() {
        XCTAssertEqual(score("logo.svg", in: "assets"), 0, "SVG is not rasterisable")
        XCTAssertEqual(score("main.swift", in: "Sources"), 0)
        XCTAssertEqual(score("README.md", in: "docs"), 0)
        XCTAssertEqual(score("screenshot.png", in: "docs"), 0)
    }
}
