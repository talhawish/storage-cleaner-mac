import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectActivityScannerIconTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testScannerLocatesXcodeAppIconOverWeakerCandidates() async throws {
        let root = temporaryDirectory.appending(path: "MyApp", directoryHint: .isDirectory)
        let appIconSet = root.appending(path: "Assets.xcassets/AppIcon.appiconset", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appIconSet, withIntermediateDirectories: true)
        try "// app".write(to: root.appending(path: "Package.swift"), atomically: true, encoding: .utf8)
        // A weaker candidate at the root plus the real app icon deeper in.
        try Data(repeating: 1, count: 100).write(to: root.appending(path: "favicon.png"))
        try Data(repeating: 2, count: 4_000).write(to: appIconSet.appending(path: "icon-1024.png"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 4)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first { $0.name == "MyApp" })

        XCTAssertEqual(project.iconURL?.lastPathComponent, "icon-1024.png")
    }

    func testScannerFindsAndroidLauncherIcon() async throws {
        let root = temporaryDirectory.appending(path: "droid", directoryHint: .isDirectory)
        let mipmap = root.appending(path: "app/src/main/res/mipmap-xxxhdpi", directoryHint: .isDirectory)
        // Creating the mipmap dir also creates the app/src/main/res chain.
        try FileManager.default.createDirectory(at: mipmap, withIntermediateDirectories: true)
        try "".write(to: root.appending(path: "settings.gradle"), atomically: true, encoding: .utf8)
        try "".write(to: root.appending(path: "app/build.gradle"), atomically: true, encoding: .utf8)
        try Data(repeating: 3, count: 2_000).write(to: mipmap.appending(path: "ic_launcher.png"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 6)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first { $0.name == "droid" })

        XCTAssertEqual(project.technology, .android)
        XCTAssertEqual(project.iconURL?.lastPathComponent, "ic_launcher.png")
    }

    func testProjectWithoutIconsHasNilIconURL() async throws {
        let root = temporaryDirectory.appending(path: "plain", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "[package]".write(to: root.appending(path: "Cargo.toml"), atomically: true, encoding: .utf8)
        try Data(repeating: 9, count: 500).write(to: root.appending(path: "main.rs"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 3)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first { $0.name == "plain" })

        XCTAssertNil(project.iconURL)
    }

    func testIconsInsideDependencyFoldersAreIgnored() async throws {
        let root = temporaryDirectory.appending(path: "web", directoryHint: .isDirectory)
        let depIcons = root.appending(path: "node_modules/some-pkg", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: depIcons, withIntermediateDirectories: true)
        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        // Only icon lives inside node_modules — must not be picked.
        try Data(repeating: 4, count: 3_000).write(to: depIcons.appending(path: "logo.png"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 4)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first { $0.name == "web" })

        XCTAssertNil(project.iconURL, "dependency-folder images are not project icons")
    }
}
