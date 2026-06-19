import Foundation
import XCTest
@testable import StorageCleaner

@MainActor
final class ProjectActivityViewModelTests: XCTestCase {
    private var projectsRoot: URL!
    private var viewModel: ProjectActivityViewModel!

    override func setUp() async throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        projectsRoot = base.appending(path: "projects", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectsRoot, withIntermediateDirectories: true)

        // Four projects spanning every activity bucket, each carrying a
        // technology-appropriate dependency directory worth reclaiming.
        try makeAgedProject(
            named: "active-node",
            marker: "package.json",
            dependencyDir: "node_modules",
            days: 1,
            dependencyBytes: 1_000
        )
        try makeAgedProject(
            named: "dormant-python",
            marker: "pyproject.toml",
            dependencyDir: "venv",
            days: 60,
            dependencyBytes: 2_000
        )
        try makeAgedProject(
            named: "inactive-rust",
            marker: "Cargo.toml",
            dependencyDir: "target",
            days: 200,
            dependencyBytes: 4_000
        )
        try makeAgedProject(
            named: "abandoned-swift",
            marker: "Package.swift",
            dependencyDir: ".build",
            days: 500,
            dependencyBytes: 8_000
        )

        viewModel = ProjectActivityViewModel(
            scanner: ProjectActivityScanner(searchPaths: [projectsRoot], maxDepth: 2),
            hibernationService: ProjectHibernationService(removal: .delete)
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: projectsRoot.deletingLastPathComponent())
    }

    func testScanPopulatesSnapshotAndResetsScanningFlag() async {
        XCTAssertFalse(viewModel.hasResults)

        await viewModel.performScan()

        XCTAssertFalse(viewModel.isScanning)
        XCTAssertTrue(viewModel.hasResults)
        XCTAssertEqual(viewModel.snapshot?.projects.count, 4)
    }

    func testActivityStatusesAreDerivedFromFileAge() async {
        await viewModel.performScan()
        let byName = Dictionary(uniqueKeysWithValues: (viewModel.snapshot?.projects ?? []).map { ($0.name, $0) })

        XCTAssertEqual(byName["active-node"]?.activityStatus, .active)
        XCTAssertEqual(byName["dormant-python"]?.activityStatus, .dormant)
        XCTAssertEqual(byName["inactive-rust"]?.activityStatus, .inactive)
        XCTAssertEqual(byName["abandoned-swift"]?.activityStatus, .abandoned)
    }

    func testInactiveProjectsAndHibernatableSizeMatchInactiveBuckets() async {
        await viewModel.performScan()

        // Candidates are projects untouched for over a month that still carry
        // reclaimable dependencies — everything except the active project.
        let inactiveNames = Set(viewModel.inactiveProjects.map(\.name))
        XCTAssertEqual(inactiveNames, ["dormant-python", "inactive-rust", "abandoned-swift"])
        // Hibernatable size is the sum of those projects' dependency bytes.
        XCTAssertEqual(viewModel.hibernatableSize, 2_000 + 4_000 + 8_000)
    }

    func testInactivityThresholdControlsCandidates() async {
        await viewModel.performScan()

        // Two weeks: every non-active project qualifies (dormant 60d, inactive
        // 200d, abandoned 500d are all ≥ 14d; active-node at 1d does not).
        viewModel.inactivityThreshold = .twoWeeks
        XCTAssertEqual(
            Set(viewModel.inactiveProjects.map(\.name)),
            ["dormant-python", "inactive-rust", "abandoned-swift"]
        )

        // Three months drops the 60-day dormant project.
        viewModel.inactivityThreshold = .threeMonths
        XCTAssertEqual(
            Set(viewModel.inactiveProjects.map(\.name)),
            ["inactive-rust", "abandoned-swift"]
        )
        XCTAssertEqual(viewModel.hibernatableSize, 4_000 + 8_000)

        // Six months keeps only the 200-day and 500-day projects.
        viewModel.inactivityThreshold = .sixMonths
        XCTAssertEqual(
            Set(viewModel.inactiveProjects.map(\.name)),
            ["inactive-rust", "abandoned-swift"]
        )

        // A very long window past every project clears the candidate list.
        viewModel.selectedStatus = nil
        XCTAssertTrue(viewModel.inactiveProjects.allSatisfy { $0.daysSinceLastModified >= 180 })
    }

    func testTechnologyFilterIsExclusiveAndTogglesOff() async {
        await viewModel.performScan()

        viewModel.toggleTechnology(.rust)
        XCTAssertTrue(viewModel.hasActiveFilters)
        XCTAssertEqual(viewModel.filteredProjects.map(\.name), ["inactive-rust"])

        viewModel.toggleTechnology(.rust)
        XCTAssertNil(viewModel.selectedTechnology)
        XCTAssertEqual(viewModel.filteredProjects.count, 4)
    }

    func testStatusFilterNarrowsProjects() async {
        await viewModel.performScan()

        viewModel.toggleStatus(.abandoned)
        XCTAssertEqual(viewModel.filteredProjects.map(\.name), ["abandoned-swift"])
    }

    func testTechnologyAndStatusFiltersCombineWithAndSemantics() async {
        await viewModel.performScan()

        viewModel.selectedTechnology = .rust
        viewModel.selectedStatus = .abandoned
        // rust is inactive (not abandoned) → no project satisfies both.
        XCTAssertTrue(viewModel.filteredProjects.isEmpty)

        viewModel.selectedStatus = .inactive
        XCTAssertEqual(viewModel.filteredProjects.map(\.name), ["inactive-rust"])
    }

    func testClearFiltersRemovesEverySelection() async {
        await viewModel.performScan()
        viewModel.selectedTechnology = .swift
        viewModel.selectedStatus = .abandoned

        viewModel.clearFilters()

        XCTAssertFalse(viewModel.hasActiveFilters)
        XCTAssertNil(viewModel.selectedTechnology)
        XCTAssertNil(viewModel.selectedStatus)
        XCTAssertEqual(viewModel.filteredProjects.count, 4)
    }

    func testHibernateReclaimsDependenciesButKeepsProject() async throws {
        await viewModel.performScan()
        let target = try XCTUnwrap(viewModel.snapshot?.projects.first { $0.name == "abandoned-swift" })

        let outcome = await viewModel.hibernate(target)

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.reclaimedBytes, 8_000)
        // The project stays in the list, now with its dependencies reclaimed.
        XCTAssertEqual(viewModel.snapshot?.projects.count, 4)
        let updated = try XCTUnwrap(viewModel.snapshot?.projects.first { $0.name == "abandoned-swift" })
        XCTAssertEqual(updated.dependencySize, 0, "dependencies cleared from the breakdown")
        XCTAssertEqual(viewModel.lastHibernation?.succeeded.count, 1)
        // The folder and its source survive; only the .build directory is gone.
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path.path), "project folder kept")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: target.path.appending(path: ".build").path),
            "dependencies removed"
        )
        // It is no longer a hibernation candidate once dependencies are gone.
        XCTAssertFalse(viewModel.inactiveProjects.contains { $0.name == "abandoned-swift" })
    }

    func testCancelScanIsSafeWhenIdle() {
        XCTAssertFalse(viewModel.isScanning)
        viewModel.cancelScan()
        XCTAssertFalse(viewModel.isScanning)
    }

    // MARK: - Helpers

    private func makeAgedProject(
        named name: String,
        marker: String,
        dependencyDir: String,
        days: Int,
        dependencyBytes: Int
    ) throws {
        let root = projectsRoot.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let markerURL = root.appending(path: marker)
        try Data(repeating: 9, count: 100).write(to: markerURL)

        // A regenerable dependency directory whose bytes hibernation reclaims.
        let dependencyRoot = root.appending(path: dependencyDir, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dependencyRoot, withIntermediateDirectories: true)
        try Data(repeating: 1, count: dependencyBytes).write(to: dependencyRoot.appending(path: "dep.bin"))

        // Activity follows the source marker, so age only that file.
        let age = Date(timeIntervalSinceNow: -Double(days) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: age], ofItemAtPath: markerURL.path)
    }
}
