import AppKit
import Foundation
import Observation

/// Abstraction over the part of `EmulatorManagementService` that the Emulators view model
/// actually consumes. Lifting this out of the concrete struct lets the view model be unit-tested
/// with a fake that returns deterministic results without going near the filesystem or
/// `xcrun` subprocesses.
protocol EmulatorsServicing: Sendable {
    func discover() async -> [EmulatorImage]
    /// Discovery plus probe diagnostics. Defaults to a diagnostics-free wrap of
    /// `discover()` so simple fakes stay one method; the live service reports
    /// real probe failures (e.g. a broken `simctl`).
    func discoverWithDiagnostics() async -> EmulatorDiscovery
    func measuringRemainingSizes(in images: [EmulatorImage]) -> [EmulatorImage]
    func remove(_ images: [EmulatorImage]) async -> EmulatorCleanupResult
}

extension EmulatorsServicing {
    func discoverWithDiagnostics() async -> EmulatorDiscovery {
        EmulatorDiscovery(images: await discover(), failureMessage: nil)
    }
}

extension EmulatorManagementService: EmulatorsServicing {}

/// Owns the Emulators view's state and lifecycle. Lifted out of the view so the loading/empty/
/// content state machine, the Rescan button, and the live-factory wiring can be unit-tested
/// without spinning up a SwiftUI host.
@MainActor
@Observable
final class EmulatorsViewModel {
    enum State: Equatable {
        case loading
        case empty
        case loaded
        case permissionRequired
        /// Discovery ran but a probe failed outright (e.g. `simctl` errored),
        /// so an empty inventory would be misleading rather than reassuring.
        case failed(message: String)
    }

    private let service: any EmulatorsServicing
    let permissionHandler: any StoragePermissionHandling

    private(set) var images: [EmulatorImage] = []
    private(set) var state: State = .loading
    private(set) var isDeleting = false
    private(set) var cleanupFailureMessage: String?
    var selectedIDs: Set<String> = []
    var showConfirmation = false
    var showCleanupFailure = false

    private var loadTask: Task<Void, Never>?
    /// Wall-clock at which the current load started. Used to keep the loading state visible
    /// long enough that the user perceives it; a filesystem walk that completes in 2 ms
    /// otherwise flashes the empty / content view with no loading affordance.
    private var loadStartedAt: Date?

    /// Gate checked before every deletion. Production wiring passes a
    /// `SubscriptionController.requirePro()` check; tests leave it open.
    /// This is the defense-in-depth layer — the UI already disables the
    /// delete button for Free users via `canUseProActions`, but if a
    /// call path bypasses the button handler, this gate catches it.
    var canDelete: @MainActor () -> Bool = { true }

    init(
        service: any EmulatorsServicing = EmulatorManagementService.live,
        permissionHandler: any StoragePermissionHandling = FileSystemPermissionService()
    ) {
        self.service = service
        self.permissionHandler = permissionHandler
    }

    // MARK: - Derived state

    var totalBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }

    var blockedPermissions: [StoragePermissionStatus] {
        permissionHandler.currentStatuses().filter { $0.state == .denied && $0.scope.isBlocking }
    }

    var selectedImages: [EmulatorImage] {
        images.filter { selectedIDs.contains($0.id) }
    }

    var selectedBytes: Int64 { selectedImages.reduce(0) { $0 + $1.bytes } }

    var sections: [(platform: EmulatorPlatform, images: [EmulatorImage])] {
        EmulatorPlatform.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { platform in
                let matching = images.filter { $0.platform == platform }
                return matching.isEmpty ? nil : (platform, matching)
            }
    }

    // MARK: - Lifecycle

    /// Triggers the initial discovery. Safe to call multiple times — the previous load is
    /// cancelled so a duplicate call never produces stale state.
    func start() {
        loadTask?.cancel()
        state = .loading
        loadStartedAt = Date()
        let statuses = permissionHandler.currentStatuses()
        let blocked = statuses.filter { $0.state == .denied && $0.scope.isBlocking }
        guard blocked.isEmpty else {
            state = .permissionRequired
            return
        }
        loadTask = Task { [weak self] in
            await self?.load()
        }
    }

    /// Attempts to grant home folder access via the system permission picker,
    /// then retries discovery. Call from the permission-required UI.
    func grantAccessAndRetry() {
        let granted = permissionHandler.requestHomeFolderAccess()
        guard granted else { return }
        start()
    }

    /// Opens System Settings to the Full Disk Access pane.
    func openSystemSettings() {
        guard let url = SystemSettingsPane.fullDiskAccess.url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Removes the supplied images while the home-folder security scope is active. Successful
    /// removals disappear immediately; failed items remain selected so the user can retry them.
    /// Returns the service's `EmulatorCleanupResult` for audit reconciliation. Checks the
    /// `canDelete` gate before proceeding — Free users get an empty result
    /// and the caller should show no UI change.
    func delete(_ toRemove: [EmulatorImage]) async -> EmulatorCleanupResult {
        guard canDelete(), !isDeleting, !toRemove.isEmpty else {
            return EmulatorCleanupResult(removedIDs: [], totalBytesReclaimed: 0, failures: [])
        }

        isDeleting = true
        cleanupFailureMessage = nil
        defer { isDeleting = false }

        let access = permissionHandler.beginHomeFolderAccess()
        defer { access?.stop() }
        let result = await service.remove(toRemove)
        let removedIDs = Set(result.removedIDs)
        images.removeAll { removedIDs.contains($0.id) }
        selectedIDs.subtract(removedIDs)
        state = images.isEmpty ? .empty : .loaded

        if !result.failures.isEmpty {
            cleanupFailureMessage = Self.failureMessage(for: result.failures, in: toRemove)
            showCleanupFailure = true
        }

        return result
    }

    /// Cancels any in-flight discovery. Called when the view disappears; the next appearance
    /// re-triggers `start()`.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    /// Rescans after a successful (or partial) removal. The caller is expected to have already
    /// removed the items; this just refreshes the inventory.
    func refreshAfterRemoval() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.load(minimumLoadingDuration: nil)
        }
    }

    func toggle(_ image: EmulatorImage) {
        guard image.isRemovable, !isDeleting else { return }
        if selectedIDs.contains(image.id) {
            selectedIDs.remove(image.id)
        } else {
            selectedIDs.insert(image.id)
        }
    }

    func toggleAll(in images: [EmulatorImage]) {
        guard !isDeleting else { return }
        let removable = images.filter(\.isRemovable).map(\.id)
        if removable.allSatisfy(selectedIDs.contains) {
            removable.forEach { selectedIDs.remove($0) }
        } else {
            removable.forEach { selectedIDs.insert($0) }
        }
    }

    // MARK: - Private

    private func load(minimumLoadingDuration: TimeInterval? = 0.4) async {
        // The Emulators view reads from `~/Library/Developer/Xcode/iOS DeviceSupport/`,
        // `~/Library/Developer/CoreSimulator/Devices/`, and `~/Library/Android/sdk/system-images/`.
        // In a sandboxed build none of these are reachable without an active security-scoped
        // bookmark on the home folder, so `discover()` would silently return [] and the user
        // would see the empty state for what is actually 50+ GB of reclaimable data. Hold the
        // scope for the whole load; if the user hasn't granted access yet, `access` is `nil`
        // and discover returns nothing — the next `start()` after they grant access picks up
        // the data.
        let access = permissionHandler.beginHomeFolderAccess()
        defer { access?.stop() }

        let discovery = await service.discoverWithDiagnostics()
        let discovered = discovery.images
        guard !Task.isCancelled else { return }

        // Two-phase sizing: show the list immediately, then fill in on-disk sizes for
        // Trash-managed folders (Device Support, simulator devices, Android images).
        apply(discovered, forceLoaded: false)

        let sized = await Task.detached(priority: .utility) { [service] in
            service.measuringRemainingSizes(in: discovered)
        }.value
        guard !Task.isCancelled else { return }
        apply(sized, forceLoaded: false)

        // Even on a fast Mac the load completes in a few ms; the loading affordance is
        // the only feedback the user gets that something happened. Hold the loading
        // state visible long enough to be perceived.
        if let minimumLoadingDuration, let started = loadStartedAt {
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < minimumLoadingDuration {
                let remaining = minimumLoadingDuration - elapsed
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled else { return }
            }
        }

        if images.isEmpty, let failure = discovery.failureMessage {
            // A failed probe with nothing to show must not masquerade as
            // "all clean" — surface the error with a retry instead.
            state = .failed(message: failure)
        } else {
            state = images.isEmpty ? .empty : .loaded
        }
    }

    private func apply(_ newImages: [EmulatorImage], forceLoaded: Bool) {
        images = newImages
        // Drop selections that no longer exist (e.g. after a removal + reload).
        selectedIDs = selectedIDs.intersection(Set(newImages.map(\.id)))
        if forceLoaded {
            state = newImages.isEmpty ? .empty : .loaded
        }
    }

    private static func failureMessage(
        for failures: [EmulatorCleanupResult.Failure],
        in requestedImages: [EmulatorImage]
    ) -> String {
        let titlesByID = Dictionary(uniqueKeysWithValues: requestedImages.map { ($0.id, $0.title) })
        let details = failures.prefix(3).map { failure in
            let title = titlesByID[failure.id] ?? "Unknown item"
            return "\(title): \(failure.message)"
        }
        let remainingCount = failures.count - details.count
        let remaining = remainingCount > 0 ? "\n…and \(remainingCount) more." : ""
        return details.joined(separator: "\n") + remaining
    }
}
