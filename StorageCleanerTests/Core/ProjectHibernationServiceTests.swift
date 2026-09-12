import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectHibernationServiceTests: XCTestCase {
    private var workingDirectory: URL!
    private var service: ProjectHibernationService!

    override func setUpWithError() throws {
        workingDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        // Hard-delete in tests so fixtures stay self-contained and the real
        // Trash is never touched; production defaults to `.trash`.
        service = ProjectHibernationService(removal: .delete)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workingDirectory)
    }

    func testHibernateRemovesDependenciesAndKeepsSource() async throws {
        let project = try makeNodeProject(named: "web-app", sourceBytes: 8_000, dependencyBytes: 40_000)
        let dependencyDir = project.path.appending(path: "node_modules", directoryHint: .isDirectory)
        let sourceFile = project.path.appending(path: "index.js")
        let expectedReclaimable = StorageFormatting.itemSize(at: dependencyDir)

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertNil(outcome.failureReason)
        XCTAssertEqual(outcome.removedDirectoryCount, 1)
        XCTAssertEqual(outcome.reclaimedBytes, expectedReclaimable)
        XCTAssertEqual(outcome.remainingDependencyBytes, 0)
        // The project folder and its source survive; only dependencies are gone.
        XCTAssertTrue(FileManager.default.fileExists(atPath: project.path.path), "project folder is kept")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path), "source file is kept")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dependencyDir.path), "dependencies removed")
    }

    func testHibernateRemovesHiddenDependencyDirectories() async throws {
        // Swift's regenerable output (`.build`) is hidden and must still be reclaimed.
        let root = workingDirectory.appending(path: "swift-pkg", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 1_000).write(to: root.appending(path: "Package.swift"))
        let build = root.appending(path: ".build", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try Data(repeating: 2, count: 25_000).write(to: build.appending(path: "artifact.o"))

        let project = ProjectInfo(
            name: "swift-pkg",
            path: root,
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 26_000,
            childProjectCount: 0,
            dependencySize: 25_000
        )
        let expectedReclaimable = StorageFormatting.itemSize(at: build)

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, expectedReclaimable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: build.path), "hidden .build removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Package.swift").path))
    }

    func testHibernatePHPProjectUsesComposerVendorFallback() async throws {
        let root = workingDirectory.appending(path: "legacy-php", directoryHint: .isDirectory)
        let vendor = root.appending(path: "vendor", directoryHint: .isDirectory)
        let unrelatedVendor = root.appending(path: "tools/vendor", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: vendor, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: unrelatedVendor, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_000).write(to: root.appending(path: "index.php"))
        try Data(repeating: 2, count: 18_000).write(to: vendor.appending(path: "autoload.php"))
        try Data(repeating: 3, count: 22_000).write(to: unrelatedVendor.appending(path: "dep.bin"))

        let project = ProjectInfo(
            name: "legacy-php",
            path: root,
            technology: .php,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 44_000,
            childProjectCount: 0,
            dependencySize: 18_000
        )
        let expectedReclaimable = StorageFormatting.itemSize(at: vendor)

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, expectedReclaimable)
        XCTAssertFalse(FileManager.default.fileExists(atPath: vendor.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedVendor.path))
    }

    func testHibernateMissingProjectFails() async throws {
        let project = ProjectInfo(
            name: "ghost",
            path: workingDirectory.appending(path: "does-not-exist", directoryHint: .isDirectory),
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 100,
            childProjectCount: 0,
            dependencySize: 0
        )

        let outcome = await service.hibernate(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, 0)
        XCTAssertNotNil(outcome.failureReason)
    }

    func testHibernateWithNoDependenciesFails() async throws {
        let root = workingDirectory.appending(path: "lean", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data(repeating: 5, count: 3_000).write(to: root.appending(path: "main.swift"))
        let project = ProjectInfo(
            name: "lean",
            path: root,
            technology: .swift,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 3_000,
            childProjectCount: 0,
            dependencySize: 0
        )

        let outcome = await service.hibernate(project)

        XCTAssertFalse(outcome.succeeded)
        XCTAssertEqual(outcome.removedDirectoryCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "main.swift").path))
    }

    func testHibernateBatchSummaryReportsReclaimedBytesAndFailures() async throws {
        let valid = try makeNodeProject(named: "valid", sourceBytes: 5_000, dependencyBytes: 12_000)
        let expectedReclaimable = StorageFormatting.itemSize(
            at: valid.path.appending(path: "node_modules", directoryHint: .isDirectory)
        )
        let missing = ProjectInfo(
            name: "missing",
            path: workingDirectory.appending(path: "nope", directoryHint: .isDirectory),
            technology: .rust,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: 4_096,
            childProjectCount: 0,
            dependencySize: 4_096
        )

        let summary = await service.hibernate([valid, missing])

        XCTAssertEqual(summary.outcomes.count, 2)
        XCTAssertEqual(summary.succeeded.count, 1)
        XCTAssertEqual(summary.failed.count, 1)
        XCTAssertEqual(summary.reclaimedBytes, expectedReclaimable, "only reclaimed allocated bytes count")
        XCTAssertEqual(summary.succeeded.first?.project.name, "valid")
        XCTAssertEqual(summary.failed.first?.project.name, "missing")
    }

    func testReactNativeHibernationIncludesNodeModules() async throws {
        let root = workingDirectory.appending(path: "react-native-app", directoryHint: .isDirectory)
        let modules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 9_000).write(to: modules.appending(path: "react-native.js"))
        let project = ProjectInfo(
            name: "react-native-app",
            path: root,
            technology: .reactNative,
            lastModifiedDate: .distantPast,
            totalSize: StorageFormatting.itemSize(at: root),
            childProjectCount: 0,
            dependencySize: StorageFormatting.itemSize(at: modules)
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modules.path))
        XCTAssertGreaterThan(outcome.reclaimedBytes, 0)
    }

    func testMixedStackMonorepoHibernationUsesComponentTechnologies() async throws {
        let root = workingDirectory.appending(path: "mixed", directoryHint: .isDirectory)
        let nodeModules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        let mobile = root.appending(path: "mobile", directoryHint: .isDirectory)
        let dartTool = mobile.appending(path: ".dart_tool", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dartTool, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_000).write(to: nodeModules.appending(path: "node.js"))
        try Data(repeating: 2, count: 6_000).write(to: dartTool.appending(path: "dart.bin"))
        let project = ProjectInfo(
            name: "mixed",
            path: root,
            technology: .nodeJS,
            components: [ProjectComponentInfo(
                name: "mobile",
                path: mobile,
                technology: .flutter,
                frameworks: []
            )],
            lastModifiedDate: .distantPast,
            totalSize: StorageFormatting.itemSize(at: root),
            childProjectCount: 1,
            dependencySize: StorageFormatting.itemSize(at: nodeModules)
                + StorageFormatting.itemSize(at: dartTool)
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.removedDirectoryCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: nodeModules.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dartTool.path))
    }

    func testRubyHibernationKeepsVendorAssetsAndRemovesVendorBundle() async throws {
        let root = workingDirectory.appending(path: "rails-app", directoryHint: .isDirectory)
        let bundle = root.appending(path: "vendor/bundle", directoryHint: .isDirectory)
        let assets = root.appending(path: "vendor/assets", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8_000).write(to: bundle.appending(path: "rails.gem"))
        try Data(repeating: 2, count: 4_000).write(to: assets.appending(path: "logo.svg"))
        let project = ProjectInfo(
            name: "rails-app",
            path: root,
            technology: .ruby,
            lastModifiedDate: .distantPast,
            totalSize: StorageFormatting.itemSize(at: root),
            childProjectCount: 0,
            dependencySize: StorageFormatting.itemSize(at: bundle)
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundle.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: assets.path), "user-owned Rails assets must remain")
    }

    func testMonorepoScopesPreventGenericDirectoryRulesBleedingAcrossSiblings() async throws {
        let root = workingDirectory.appending(path: "polyglot", directoryHint: .isDirectory)
        let goRoot = root.appending(path: "api", directoryHint: .isDirectory)
        let goVendor = goRoot.appending(path: "vendor", directoryHint: .isDirectory)
        let rubyRoot = root.appending(path: "admin", directoryHint: .isDirectory)
        let rubyBundle = rubyRoot.appending(path: "vendor/bundle", directoryHint: .isDirectory)
        let rubyAssets = rubyRoot.appending(path: "vendor/assets", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: goVendor, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rubyBundle, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rubyAssets, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 4_000).write(to: goVendor.appending(path: "module.go"))
        try Data(repeating: 2, count: 6_000).write(to: rubyBundle.appending(path: "rails.gem"))
        try Data(repeating: 3, count: 8_000).write(to: rubyAssets.appending(path: "logo.svg"))

        let project = ProjectInfo(
            name: "polyglot",
            path: root,
            technology: .nodeJS,
            components: [
                ProjectComponentInfo(name: "api", path: goRoot, technology: .golang, frameworks: []),
                ProjectComponentInfo(name: "admin", path: rubyRoot, technology: .ruby, frameworks: [])
            ],
            lastModifiedDate: .distantPast,
            totalSize: StorageFormatting.itemSize(at: root),
            childProjectCount: 2,
            dependencySize: StorageFormatting.itemSize(at: goVendor)
                + StorageFormatting.itemSize(at: rubyBundle)
        )

        let outcome = await service.hibernate(project)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.removedDirectoryCount, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: goVendor.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: rubyBundle.path))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: rubyAssets.path),
            "a Go sibling's generic vendor rule must never remove Ruby-owned assets"
        )
    }

    // MARK: - Helpers

    private func makeNodeProject(named name: String, sourceBytes: Int, dependencyBytes: Int) throws -> ProjectInfo {
        let root = workingDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "{}".write(to: root.appending(path: "package.json"), atomically: true, encoding: .utf8)
        try Data(repeating: 7, count: sourceBytes).write(to: root.appending(path: "index.js"))

        let modules = root.appending(path: "node_modules", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: modules, withIntermediateDirectories: true)
        try Data(repeating: 8, count: dependencyBytes).write(to: modules.appending(path: "dep.js"))

        return ProjectInfo(
            name: name,
            path: root,
            technology: .nodeJS,
            lastModifiedDate: Date(timeIntervalSince1970: 0),
            totalSize: Int64(sourceBytes + dependencyBytes + 2),
            childProjectCount: 0,
            dependencySize: Int64(dependencyBytes)
        )
    }
}
