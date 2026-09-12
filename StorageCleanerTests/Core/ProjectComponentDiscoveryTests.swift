import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectComponentDiscoveryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testMonorepoComponentsAggregateFrameworksWithoutDoubleCountingRoot() async throws {
        let root = try makeDirectory("auto-marketing")
        try writePackage([:], to: root)
        try makeNuxtComponent(named: "dashboard", under: root)
        try makeNuxtComponent(named: "landing", under: root)

        let scanner = ProjectActivityScanner(
            searchPaths: [temporaryDirectory],
            maxDepth: 2,
            minimumProjectSize: 1
        )
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)

        XCTAssertEqual(snapshot.projects.count, 1, "nested workspaces must not duplicate root storage")
        XCTAssertEqual(project.components.map(\.name), ["dashboard", "landing"])
        XCTAssertEqual(project.frameworks, [.nuxt, .vue])
        XCTAssertEqual(project.frameworkProjectCounts, [.nuxt: 2, .vue: 2])
        XCTAssertEqual(project.iconFallback, .nuxt)
        XCTAssertEqual(project.totalSize, StorageFormatting.itemSize(at: root))
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: snapshot.frameworkBreakdown.map { ($0.framework, $0.count) }),
            [.nuxt: 2, .vue: 2]
        )
    }

    func testDiscoversWorkspaceProjectBelowAContainerDirectory() throws {
        let root = try makeDirectory("workspace")
        try writePackage([:], to: root)
        let web = try makeDirectory("apps/web", under: root)
        try writePackage(["next": "15", "react": "19"], to: web)

        let components = ProjectComponentDiscovery.discover(in: root, rootTechnology: .nodeJS)

        XCTAssertEqual(
            components.map { $0.path.resolvingSymlinksInPath() },
            [web.resolvingSymlinksInPath()]
        )
        XCTAssertEqual(components.first?.frameworks, [.nextJS, .react])
    }

    func testFlutterPlatformFoldersAreNotReportedAsIndependentProjects() throws {
        let root = try makeDirectory("flutter-app")
        try "name: flutter_app".write(
            to: root.appending(path: "pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )
        let android = try makeDirectory("android", under: root)
        try "plugins {}".write(
            to: android.appending(path: "build.gradle"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertTrue(ProjectComponentDiscovery.discover(in: root, rootTechnology: .flutter).isEmpty)
    }

    func testMixedStackMonorepoMeasuresEveryComponentsDependencies() async throws {
        let root = try makeDirectory("mixed-workspace")
        try writePackage([:], to: root)
        let nodeModules = try makeDirectory("node_modules", under: root)
        try Data(repeating: 1, count: 8_000).write(to: nodeModules.appending(path: "node.js"))

        let mobile = try makeDirectory("mobile", under: root)
        try "name: mobile".write(
            to: mobile.appending(path: "pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )
        let dartTool = try makeDirectory(".dart_tool", under: mobile)
        try Data(repeating: 2, count: 12_000).write(to: dartTool.appending(path: "cache.bin"))

        let scanner = ProjectActivityScanner(
            searchPaths: [temporaryDirectory],
            maxDepth: 2,
            minimumProjectSize: 1
        )
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)
        let expectedDependencies = StorageFormatting.itemSize(at: nodeModules)
            + StorageFormatting.itemSize(at: dartTool)

        XCTAssertEqual(project.technologies, [.nodeJS, .flutter])
        XCTAssertEqual(project.dependencySize, expectedDependencies)
    }

    func testPolyglotComponentCombinesFrameworksAndDependencyRulesAtOneBoundary() async throws {
        let root = try makeDirectory("workspace")
        try writePackage([:], to: root)
        let admin = try makeDirectory("admin", under: root)
        try writePackage(["vue": "3"], to: admin)
        let composerData = try JSONSerialization.data(withJSONObject: [
            "require": ["laravel/framework": "^12.0"]
        ])
        try composerData.write(to: admin.appending(path: "composer.json"))

        let modules = try makeDirectory("node_modules", under: admin)
        try Data(repeating: 1, count: 4_000).write(to: modules.appending(path: "vue.js"))
        let vendor = try makeDirectory("vendor", under: admin)
        try Data(repeating: 2, count: 6_000).write(to: vendor.appending(path: "autoload.php"))

        let scanner = ProjectActivityScanner(
            searchPaths: [temporaryDirectory],
            maxDepth: 2,
            minimumProjectSize: 1
        )
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)
        let component = try XCTUnwrap(project.components.first)

        XCTAssertEqual(component.technology, .php)
        XCTAssertEqual(component.technologies, [.php, .nodeJS])
        XCTAssertEqual(component.frameworks, [.laravel, .vue])
        XCTAssertEqual(project.frameworks, [.laravel, .vue])
        XCTAssertEqual(
            project.dependencySize,
            StorageFormatting.itemSize(at: modules) + StorageFormatting.itemSize(at: vendor)
        )
    }

    private func makeNuxtComponent(named name: String, under root: URL) throws {
        let component = try makeDirectory(name, under: root)
        try writePackage(["nuxt": "4", "vue": "3"], to: component)
        try Data(repeating: 3, count: 1_000).write(to: component.appending(path: "app.vue"))
    }

    private func writePackage(_ dependencies: [String: String], to directory: URL) throws {
        let object: [String: Any] = ["private": true, "dependencies": dependencies]
        let data = try JSONSerialization.data(withJSONObject: object)
        try data.write(to: directory.appending(path: "package.json"))
    }

    private func makeDirectory(_ path: String, under parent: URL? = nil) throws -> URL {
        let directory = (parent ?? temporaryDirectory)
            .appending(path: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
