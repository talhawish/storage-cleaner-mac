import AppKit
import Foundation
import Observation

/// Owns the Project Activity screen's state: scanning (cancellable), filtering
/// by technology and activity, and hibernation. Keeps all logic out of the view.
@MainActor
@Observable
final class ProjectActivityViewModel {
    private let scanner: ProjectActivityScanner
    private let hibernationService: ProjectHibernationService
    private let compressionService: any ProjectCompressionServicing
    private let permissionHandler: (any StoragePermissionHandling)?
    private var scanTask: Task<Void, Never>?

    private(set) var snapshot: ProjectActivitySnapshot?
    private(set) var isScanning = false
    private(set) var hasScanned = false
    private(set) var lastHibernation: HibernationSummary?
    private(set) var lastCompression: CompressionOutcome?
    var selectedTechnology: ProjectTechnology?
    var selectedStatus: ProjectActivityStatus?

    /// How long a project must be untouched before it is offered for
    /// hibernation. Driven by the user's Settings choice.
    var inactivityThreshold: InactivityThreshold = .oneMonth

    /// `true` when a scan ran but could not access the home directory (sandbox
    /// missing the security-scoped bookmark). The view can show a permission
    /// prompt instead of a generic empty state.
    var accessDenied: Bool {
        snapshot?.accessDenied ?? false
    }

    init(
        scanner: ProjectActivityScanner = ProjectActivityScanner(),
        hibernationService: ProjectHibernationService = ProjectHibernationService(),
        compressionService: any ProjectCompressionServicing = ProjectCompressionService(),
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) {
        self.scanner = scanner
        self.hibernationService = hibernationService
        self.compressionService = compressionService
        self.permissionHandler = permissionHandler
    }

    // MARK: - Derived state

    var hasResults: Bool {
        !(snapshot?.projects.isEmpty ?? true)
    }

    var hasActiveFilters: Bool {
        selectedTechnology != nil || selectedStatus != nil
    }

    var filteredProjects: [ProjectInfo] {
        applyFilters(to: snapshot?.projects ?? [])
    }

    var inactiveProjects: [ProjectInfo] {
        applyFilters(to: snapshot?.inactiveProjects(olderThan: inactivityThreshold) ?? [])
    }

    /// Space hibernation can reclaim from the inactive projects in scope: the
    /// sum of their regenerable dependency sizes. Computed from the live project
    /// list so it always matches what the user sees.
    var hibernatableSize: Int64 {
        inactiveProjects.reduce(0) { $0 + $1.dependencySize }
    }

    private func applyFilters(to projects: [ProjectInfo]) -> [ProjectInfo] {
        projects.filter { project in
            if let selectedTechnology, project.technology != selectedTechnology { return false }
            if let selectedStatus, project.activityStatus != selectedStatus { return false }
            return true
        }
    }

    // MARK: - Scanning

    func scan() {
        guard !isScanning else { return }
        scanTask = Task { await performScan() }
    }

    /// The awaitable scan core. Separated from `scan()` so it can be driven
    /// deterministically in tests without polling `isScanning`.
    func performScan() async {
        isScanning = true
        lastHibernation = nil
        let result = await scanner.scan()
        guard !Task.isCancelled else {
            isScanning = false
            return
        }
        snapshot = result
        hasScanned = true
        isScanning = false
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    @discardableResult
    func grantHomeFolderAccess() -> Bool {
        guard permissionHandler?.requestHomeFolderAccess() == true else { return false }
        scan()
        return true
    }

    func openSystemSettings() {
        guard let url = SystemSettingsPane.fullDiskAccess.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Filtering

    func toggleTechnology(_ technology: ProjectTechnology) {
        selectedTechnology = selectedTechnology == technology ? nil : technology
    }

    func toggleStatus(_ status: ProjectActivityStatus) {
        selectedStatus = selectedStatus == status ? nil : status
    }

    func clearFilters() {
        selectedTechnology = nil
        selectedStatus = nil
    }

    // MARK: - Hibernation

    @discardableResult
    func hibernate(_ projects: [ProjectInfo]) async -> HibernationSummary {
        let summary = await hibernationService.hibernate(projects)
        updateDependencies(from: summary.outcomes)
        lastHibernation = summary
        return summary
    }

    func hibernate(_ project: ProjectInfo) async -> HibernationOutcome {
        let summary = await hibernate([project])
        return summary.outcomes.first
            ?? HibernationOutcome(
                project: project,
                reclaimedBytes: 0,
                removedDirectoryCount: 0,
                remainingDependencyBytes: project.dependencySize,
                failureReason: "Hibernation did not run."
            )
    }

    /// Reflect a successful hibernation in place: the projects stay in the list
    /// but with their reclaimed dependencies removed from the size breakdown.
    /// Re-sorts by size to preserve the snapshot's largest-first ordering.
    private func updateDependencies(from outcomes: [HibernationOutcome]) {
        guard !outcomes.isEmpty else { return }
        let remainingByID = Dictionary(
            uniqueKeysWithValues: outcomes.map { ($0.id, $0.remainingDependencyBytes) }
        )
        updateDependencySizes(remainingByID)
    }

    private func updateDependencySizes(_ remainingByID: [UUID: Int64]) {
        guard let snapshot, !remainingByID.isEmpty else { return }
        let updated = snapshot.projects
            .map { project in
                guard let remaining = remainingByID[project.id] else { return project }
                return project.withDependencySize(remaining)
            }
            .sorted { $0.totalSize > $1.totalSize }
        self.snapshot = ProjectActivitySnapshot(
            projects: updated,
            scannedAt: snapshot.scannedAt,
            scanDuration: snapshot.scanDuration
        )
    }

    // MARK: - Compression

    /// Hibernates a single project and, on success, compresses it into a zip
    /// archive next to the original folder. The original folder is removed
    /// only after the archive is verified, so a partial or invalid zip never
    /// destroys the project.
    ///
    /// On success the project is removed from the snapshot entirely (its
    /// folder is gone). On failure the snapshot is left untouched so the user
    /// can retry.
    @discardableResult
    func compress(_ project: ProjectInfo) async -> CompressionOutcome {
        let outcome = await compressionService.compress(project)
        lastCompression = outcome
        if outcome.succeeded {
            removeProjectFromSnapshot(id: project.id)
        } else if outcome.reclaimedDependencyBytes > 0 {
            let remaining = max(0, project.dependencySize - outcome.reclaimedDependencyBytes)
            updateDependencySize(forProjectID: project.id, remainingBytes: remaining)
        }
        return outcome
    }

    private func updateDependencySize(forProjectID id: UUID, remainingBytes: Int64) {
        updateDependencySizes([id: remainingBytes])
    }

    private func removeProjectFromSnapshot(id: UUID) {
        guard let snapshot else { return }
        let updated = snapshot.projects.filter { $0.id != id }
        guard updated.count != snapshot.projects.count else { return }
        self.snapshot = ProjectActivitySnapshot(
            projects: updated,
            scannedAt: snapshot.scannedAt,
            scanDuration: snapshot.scanDuration
        )
    }
}
