import Foundation
import XCTest
@testable import StorageCleaner

final class ReactNativeStorageScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testAggregatesBuildArtifactsAcrossProjects() async throws {
        let projectA = temporaryDirectory.appending(path: "rn_app_a", directoryHint: .isDirectory)
        let projectB = temporaryDirectory.appending(path: "rn_app_b", directoryHint: .isDirectory)
        let plainNode = temporaryDirectory.appending(path: "plain_node", directoryHint: .isDirectory)

        for project in [projectA, projectB, plainNode] {
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        }

        let packageJSONWithRN = #"{"dependencies":{"react-native":"0.73.0"}}"#
        let packageJSONPlain = #"{"dependencies":{"next":"14.0.0"}}"#

        try packageJSONWithRN.write(to: projectA.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try packageJSONWithRN.write(to: projectB.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try packageJSONPlain.write(to: plainNode.appending(path: "package.json"), atomically: true, encoding: .utf8)

        let iosPodsA = projectA.appending(path: "ios/Pods", directoryHint: .isDirectory)
        let iosBuildA = projectA.appending(path: "ios/build", directoryHint: .isDirectory)
        let androidBuildA = projectA.appending(path: "android/app/build", directoryHint: .isDirectory)
        let androidGradleB = projectB.appending(path: "android/.gradle", directoryHint: .isDirectory)
        for path in [iosPodsA, iosBuildA, androidBuildA, androidGradleB] {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        try Data(repeating: 1, count: 10_000).write(to: iosPodsA.appending(path: "Pods.xcodeproj"))
        try Data(repeating: 2, count: 20_000).write(to: iosBuildA.appending(path: "Build.a"))
        try Data(repeating: 3, count: 30_000).write(to: androidBuildA.appending(path: "app-debug.apk"))
        try Data(repeating: 4, count: 40_000).write(to: androidGradleB.appending(path: "cache.bin"))

        // A `build` folder inside plain_node must not be counted — it's not an RN project.
        let plainBuild = plainNode.appending(path: "build", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: plainBuild, withIntermediateDirectories: true)
        try Data(repeating: 9, count: 99_000).write(to: plainBuild.appending(path: "output.js"))

        let scanner = ReactNativeStorageScanner(
            projectRoots: [temporaryDirectory],
            maxDepth: 3,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()
        let paths = Set(result.finding?.filePaths.map(\.standardizedFileURL) ?? [])

        XCTAssertEqual(result.finding?.kind, .reactNativeArtifacts)
        XCTAssertEqual(result.finding?.domain, .mobileDevelopment)
        XCTAssertEqual(result.finding?.safety, .review)
        XCTAssertEqual(result.finding?.itemCount, 4)
        XCTAssertEqual(paths, Set([
            iosPodsA.standardizedFileURL,
            iosBuildA.standardizedFileURL,
            androidBuildA.standardizedFileURL,
            androidGradleB.standardizedFileURL
        ]))
        XCTAssertFalse(paths.contains(plainBuild.standardizedFileURL), "plain Node.js `build` is not an RN artifact")
        // 4 KiB block alignment: 10K→3, 20K→5, 30K→8, 40K→10 blocks = 12_288 + 20_480 + 32_768 + 40_960.
        XCTAssertEqual(result.finding?.bytes, 106_496)
    }

    func testReturnsNoFindingWhenNoProjects() async throws {
        let scanner = ReactNativeStorageScanner(
            projectRoots: [temporaryDirectory],
            maxDepth: 2,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertNil(result.finding)
        XCTAssertEqual(result.inspectedItemCount, 0)
    }

    func testIgnoresProjectsWithoutBuildArtifacts() async throws {
        let project = temporaryDirectory.appending(path: "rn_clean", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try #"{"dependencies":{"react-native":"0.73.0"}}"#.write(
            to: project.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        let scanner = ReactNativeStorageScanner(
            projectRoots: [temporaryDirectory],
            maxDepth: 2,
            collector: FileSystemCollector()
        )

        let result = await scanner.scan()

        XCTAssertNil(result.finding, "an RN project with no build dirs has nothing to clean")
    }
}
