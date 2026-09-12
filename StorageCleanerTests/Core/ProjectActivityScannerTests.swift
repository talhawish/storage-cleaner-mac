import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectActivityScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    // MARK: - Detection

    func testDetectsEverySupportedTechnologyFromItsPrimaryMarker() throws {
        let cases: [(ProjectTechnology, String)] = [
            (.flutter, "pubspec.yaml"),
            (.swift, "Package.swift"),
            (.rust, "Cargo.toml"),
            (.golang, "go.mod"),
            (.php, "composer.json"),
            (.python, "pyproject.toml"),
            (.ruby, "Gemfile"),
            (.nodeJS, "package.json"),
            (.kotlin, "build.gradle.kts"),
            (.java, "pom.xml")
        ]

        for (technology, marker) in cases {
            let root = try makeProject(named: technology.rawValue, marker: marker)
            XCTAssertEqual(ProjectDetector.detect(at: root), technology, "expected \(technology) from \(marker)")
        }
    }

    func testDetectsReactNativeFromPackageJSONDependency() throws {
        let root = try makeProject(named: "rn_app", marker: "package.json")
        try #"{"dependencies":{"react-native":"^0.73.0"}}"#.write(
            to: root.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectDetector.detect(at: root), .reactNative)
    }

    func testReactNativeTakesPriorityOverPlainNodeJS() throws {
        let root = try makeProject(named: "rn_prio", marker: "package.json")
        try #"{"dependencies":{"react-native":"0.73.0","react":"18.2.0"}}"#.write(
            to: root.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectDetector.detect(at: root), .reactNative, "react-native wins over plain node")
    }

    func testPackageJSONWithoutReactNativeFallsBackToNodeJS() throws {
        let root = try makeProject(named: "plain_node", marker: "package.json")
        try #"{"dependencies":{"react":"18.2.0","next":"14.0.0"}}"#.write(
            to: root.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectDetector.detect(at: root), .nodeJS)
    }

    func testNodeIconFallbackDetectsNextAndNuxt() async throws {
        let next = try makeProject(named: "next_app", marker: "package.json")
        try #"{"dependencies":{"next":"14.0.0","react":"18.2.0"}}"#.write(
            to: next.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 1, count: 1_000).write(to: next.appending(path: "page.tsx"))

        let nuxt = try makeProject(named: "nuxt_app", marker: "package.json")
        try #"{"dependencies":{"nuxt":"3.0.0","vue":"3.4.0"}}"#.write(
            to: nuxt.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 2, count: 1_000).write(to: nuxt.appending(path: "app.vue"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2, minimumProjectSize: 1)
        let snapshot = await scanner.scan()

        XCTAssertEqual(snapshot.projects.first { $0.name == "next_app" }?.iconFallback, .nextJS)
        XCTAssertEqual(snapshot.projects.first { $0.name == "next_app" }?.frameworks, [.nextJS, .react])
        XCTAssertEqual(snapshot.projects.first { $0.name == "nuxt_app" }?.iconFallback, .nuxt)
        XCTAssertEqual(snapshot.projects.first { $0.name == "nuxt_app" }?.frameworks, [.nuxt, .vue])
    }

    func testFrameworkIconFallbacksDetectLaravelAndDjango() async throws {
        let laravel = try makeProject(named: "laravel_app", marker: "composer.json")
        try #"{"require":{"laravel/framework":"^11.0"}}"#.write(
            to: laravel.appending(path: "composer.json"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 3, count: 1_000).write(to: laravel.appending(path: "index.php"))

        let django = try makeProject(named: "django_app", marker: "requirements.txt")
        try "Django==5.0".write(to: django.appending(path: "requirements.txt"), atomically: true, encoding: .utf8)
        try Data(repeating: 4, count: 1_000).write(to: django.appending(path: "views.py"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2, minimumProjectSize: 1)
        let snapshot = await scanner.scan()

        XCTAssertEqual(snapshot.projects.first { $0.name == "laravel_app" }?.iconFallback, .laravel)
        XCTAssertEqual(snapshot.projects.first { $0.name == "laravel_app" }?.frameworks, [.laravel])
        XCTAssertEqual(snapshot.projects.first { $0.name == "django_app" }?.iconFallback, .django)
        XCTAssertEqual(snapshot.projects.first { $0.name == "django_app" }?.frameworks, [.django])
    }

    func testEmptyPackageJSONIsNotReactNative() throws {
        let root = try makeProject(named: "empty_pkg", marker: "package.json")
        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectDetector.detect(at: root), .nodeJS, "a package.json with no react-native is plain Node")
    }

    func testDetectsExtensionBasedMarkers() throws {
        let dotNet = try makeProject(named: "Api", marker: "Api.csproj")
        XCTAssertEqual(ProjectDetector.detect(at: dotNet), .dotNet)

        // A `.xcodeproj` is itself a directory entry, so Swift is detected on the
        // parent folder that contains it.
        let swiftRoot = temporaryDirectory.appending(path: "MyApp", directoryHint: .isDirectory)
        let xcodeproj = swiftRoot.appending(path: "MyApp.xcodeproj", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        XCTAssertEqual(ProjectDetector.detect(at: swiftRoot), .swift)
    }

    func testFlutterTakesPriorityOverAndroidAndGradle() throws {
        let root = temporaryDirectory.appending(path: "flutter_app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "name: app".write(to: root.appending(path: "pubspec.yaml"), atomically: true, encoding: .utf8)
        // A real Flutter project also contains a Gradle-based android module.
        let androidApp = root.appending(path: "android/app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: androidApp, withIntermediateDirectories: true)
        try "".write(to: androidApp.appending(path: "build.gradle"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectDetector.detect(at: root), .flutter)
    }

    func testAndroidTakesPriorityOverGenericGradle() throws {
        let root = temporaryDirectory.appending(path: "android_app", directoryHint: .isDirectory)
        let appModule = root.appending(path: "app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appModule, withIntermediateDirectories: true)
        try "".write(to: root.appending(path: "build.gradle"), atomically: true, encoding: .utf8)
        try "".write(to: root.appending(path: "settings.gradle"), atomically: true, encoding: .utf8)
        try "".write(to: appModule.appending(path: "build.gradle"), atomically: true, encoding: .utf8)

        XCTAssertEqual(ProjectDetector.detect(at: root), .android)
    }

    func testEmptyDirectoryIsNotAProject() throws {
        let root = temporaryDirectory.appending(path: "empty", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertNil(ProjectDetector.detect(at: root))
    }

    func testEveryTechnologyHasMarkersAndValidSymbol() {
        for technology in ProjectTechnology.allCases {
            XCTAssertFalse(technology.markerFiles.isEmpty, "\(technology) has no markers")
            XCTAssertFalse(technology.symbolName.isEmpty)
            XCTAssertEqual(technology.color.count, 6, "\(technology) colour must be a 6-digit hex")
        }
    }

    // MARK: - Scanning & metrics

    func testScanDiscoversProjectsAndSeparatesDependencySize() async throws {
        let root = temporaryDirectory.appending(path: "node_app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 10_000).write(to: root.appending(path: "index.js"))

        let modules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 40_000).write(to: modules.appending(path: "dep.js"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 3, minimumProjectSize: 1)
        let snapshot = await scanner.scan()

        let project = try XCTUnwrap(snapshot.projects.first { $0.name == "node_app" })
        let expectedDependencies = StorageFormatting.itemSize(at: modules)
        let expectedTotal = StorageFormatting.itemSize(at: root)
        XCTAssertEqual(project.technology, .nodeJS)
        XCTAssertEqual(project.totalSize, expectedTotal)
        XCTAssertEqual(project.dependencySize, expectedDependencies)
        XCTAssertEqual(project.projectSize, expectedTotal - expectedDependencies)
    }

    func testPHPProjectActivityUsesComposerVendorFallback() async throws {
        let root = temporaryDirectory.appending(path: "legacy_php", directoryHint: .isDirectory)
        let vendor = root.appending(path: "vendor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vendor, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8_000).write(to: root.appending(path: "index.php"))
        try Data(repeating: 2, count: 20_000).write(to: vendor.appending(path: "autoload.php"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2, minimumProjectSize: 1)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)
        let expectedDependencies = StorageFormatting.itemSize(at: vendor)

        XCTAssertEqual(project.technology, .php)
        XCTAssertEqual(project.dependencySize, expectedDependencies)
        XCTAssertEqual(project.projectSize, StorageFormatting.itemSize(at: root) - expectedDependencies)
    }

    func testHiddenDependenciesAndRepositoryDataAreIncludedInAllocatedSize() async throws {
        let root = temporaryDirectory.appending(path: "swift_pkg", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "// pkg".write(to: root.appending(path: "Package.swift"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 6_000).write(to: root.appending(path: "main.swift"))

        // `.build` is a hidden dependency directory: its bytes must be reclaimed.
        let build = root.appending(path: ".build", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 20_000).write(to: build.appending(path: "artifact.o"))

        // `.git` is hidden but not a dependency: it should not skew size or activity.
        let git = root.appending(path: ".git", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        try Data(repeating: 3, count: 9_000).write(to: git.appending(path: "objects.pack"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 3, minimumProjectSize: 1)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)

        XCTAssertEqual(project.technology, .swift)
        XCTAssertEqual(project.dependencySize, StorageFormatting.itemSize(at: build), "hidden .build is reclaimable")
        XCTAssertEqual(
            project.totalSize,
            StorageFormatting.itemSize(at: root),
            ".git still consumes project disk space"
        )
    }

    func testScannerDoesNotDescendIntoDetectedProjects() async throws {
        let outer = temporaryDirectory.appending(path: "outer", directoryHint: .isDirectory)
        let nested = outer.appending(path: "nested", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "{}".write(to: outer.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try "[package]".write(to: nested.appending(path: "Cargo.toml"), atomically: true, encoding: .utf8)

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 4, minimumProjectSize: 1)
        let snapshot = await scanner.scan()

        XCTAssertEqual(snapshot.projects.count, 1)
        XCTAssertEqual(snapshot.projects.first?.technology, .nodeJS)
        XCTAssertEqual(snapshot.projects.first?.childProjectCount, 1)
    }

    func testSnapshotIsSortedBySizeAndDeduplicatesAcrossOverlappingRoots() async throws {
        let big = temporaryDirectory.appending(path: "big", directoryHint: .isDirectory)
        let small = temporaryDirectory.appending(path: "small", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: big, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: small, withIntermediateDirectories: true)
        try "{}".write(to: big.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 30_000).write(to: big.appending(path: "app.js"))
        try "{}".write(to: small.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 1, count: 1_000).write(to: small.appending(path: "app.js"))

        // The same root is listed twice; each project must appear only once.
        let scanner = ProjectActivityScanner(
            searchPaths: [temporaryDirectory, temporaryDirectory],
            maxDepth: 2,
            minimumProjectSize: 1
        )
        let snapshot = await scanner.scan()

        XCTAssertEqual(snapshot.projects.count, 2)
        XCTAssertEqual(snapshot.projects.map(\.name), ["big", "small"], "sorted by size descending")
        XCTAssertGreaterThanOrEqual(snapshot.scanDuration, 0)
        XCTAssertEqual(snapshot.totalSize, snapshot.projects.reduce(0) { $0 + $1.totalSize })
    }

    func testOverlappingSearchRootsAreCollapsedBeforeScanning() {
        let documents = temporaryDirectory.appending(path: "Documents", directoryHint: .isDirectory)
        let github = documents.appending(path: "GitHub", directoryHint: .isDirectory)
        let desktop = temporaryDirectory.appending(path: "Desktop", directoryHint: .isDirectory)

        let roots = ProjectActivityScanner.nonOverlappingSearchRoots([github, documents, desktop, documents])

        XCTAssertEqual(Set(roots), Set([documents.standardizedFileURL, desktop.standardizedFileURL]))
    }

    func testRecentDependencyFilesDoNotCountAsProjectActivity() async throws {
        let root = temporaryDirectory.appending(path: "stale_app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appending(path: "package.json")
        try "{}".write(to: source, atomically: true, encoding: .utf8)

        // A freshly-installed dependency should NOT make the project look active.
        let modules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 5_000).write(to: modules.appending(path: "fresh.js"))

        let oldDate = Date(timeIntervalSinceNow: -400 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: source.path)

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2, minimumProjectSize: 1)
        let snapshot = await scanner.scan()
        let project = try XCTUnwrap(snapshot.projects.first)

        XCTAssertEqual(project.activityStatus, .abandoned, "activity follows source files, not dependencies")
    }

    func testDefaultScanFiltersTinyMarkerOnlyFolders() async throws {
        let root = temporaryDirectory.appending(path: "tiny_fixture", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "name: fixture".write(to: root.appending(path: "pubspec.yaml"), atomically: true, encoding: .utf8)
        try "void main() {}".write(to: root.appending(path: "main.dart"), atomically: true, encoding: .utf8)

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2)
        let snapshot = await scanner.scan()

        XCTAssertTrue(snapshot.projects.isEmpty)
    }

    func testScanSkipsNestedPackagesInsideFlutterSDKCheckout() async throws {
        let sdkRoot = temporaryDirectory.appending(path: "flutter", directoryHint: .isDirectory)
        let internalPackage = sdkRoot.appending(path: "engine/src/flutter", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: sdkRoot.appending(path: "bin", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: sdkRoot.appending(path: "packages/flutter/lib", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: internalPackage, withIntermediateDirectories: true)

        try "#!/bin/sh".write(to: sdkRoot.appending(path: "bin/flutter"), atomically: true, encoding: .utf8)
        try "sdk internals".write(
            to: sdkRoot.appending(path: "packages/flutter/lib/framework.dart"),
            atomically: true,
            encoding: .utf8
        )
        try "name: flutter".write(
            to: internalPackage.appending(path: "pubspec.yaml"),
            atomically: true,
            encoding: .utf8
        )
        try Data(repeating: 7, count: 1_200_000).write(to: internalPackage.appending(path: "framework.dart"))

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 6)
        let snapshot = await scanner.scan()

        XCTAssertTrue(snapshot.projects.isEmpty)
    }

    func testScanningEmptyRootsProducesNoProjects() async {
        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2)
        let snapshot = await scanner.scan()
        XCTAssertTrue(snapshot.projects.isEmpty)
        XCTAssertEqual(snapshot.totalSize, 0)
        XCTAssertEqual(snapshot.hibernatableSize(olderThan: .oneMonth), 0)
    }

    // MARK: - Status

    func testActivityStatusThresholds() {
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 5), .active)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 60), .dormant)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 200), .inactive)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 500), .abandoned)
    }

    func testActivityStatusBoundariesAreInclusiveLowerBound() {
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 0), .active)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 29), .active)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 30), .dormant)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 89), .dormant)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 90), .inactive)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 364), .inactive)
        XCTAssertEqual(ProjectActivityStatus.from(daysSinceLastModified: 365), .abandoned)
    }

    func testEverySymbolAndColorIsDistinctPerTechnology() {
        let symbols = ProjectTechnology.allCases.map(\.symbolName)
        let colors = ProjectTechnology.allCases.map(\.color)
        XCTAssertEqual(Set(symbols).count, symbols.count, "each technology needs a distinct icon")
        XCTAssertEqual(Set(colors).count, colors.count, "each technology needs a distinct colour")
    }

    func testEveryIconFallbackHasDisplayMetadata() {
        for fallback in ProjectIconFallback.allCases {
            XCTAssertFalse(fallback.symbolName.isEmpty)
            XCTAssertEqual(fallback.color.count, 6, "\(fallback) colour must be a 6-digit hex")
        }
    }

    // MARK: - Helpers

    private func makeProject(named name: String, marker: String) throws -> URL {
        let root = temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "marker".write(to: root.appending(path: marker), atomically: true, encoding: .utf8)
        return root
    }
}
