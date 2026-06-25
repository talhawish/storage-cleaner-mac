import AppKit
import Foundation
import Observation

/// Abstraction over the part of `EmulatorManagementService` that the Emulators view model
/// actually consumes. Lifting this out of the concrete struct lets the view model be unit-tested
/// with a fake that returns deterministic results without going near the filesystem or
/// `xcrun` subprocesses.
protocol EmulatorsServicing: Sendable {
    func discover() async -> [EmulatorImage]
    func measuringRemainingSizes(in images: [EmulatorImage]) -> [EmulatorImage]
    func remove(_ images: [EmulatorImage]) async -> EmulatorCleanupResult
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
    }

    private let service: any EmulatorsServicing
    let permissionHandler: any StoragePermissionHandling

    private(set) var images: [EmulatorImage] = []
    private(set) var state: State = .loading
    var selectedIDs: Set<String> = []
    var showConfirmation = false

    private var loadTask: Task<Void, Never>?
    /// Wall-clock at which the current load started. Used to keep the loading state visible
    /// long enough that the user perceives it; a filesystem walk that completes in 2 ms
    /// otherwise flashes the empty / content view with no loading affordance.
    private var loadStartedAt: Date?

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

    /// Removes the supplied images using the injected service. Returns the service's
    /// `EmulatorCleanupResult` so the caller can surface failures.
    func delete(_ toRemove: [EmulatorImage]) async -> EmulatorCleanupResult {
        await service.remove(toRemove)
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
        start()
    }

    func toggle(_ image: EmulatorImage) {
        guard image.isRemovable else { return }
        if selectedIDs.contains(image.id) {
            selectedIDs.remove(image.id)
        } else {
            selectedIDs.insert(image.id)
        }
    }

    func toggleAll(in images: [EmulatorImage]) {
        let removable = images.filter(\.isRemovable).map(\.id)
        if removable.allSatisfy(selectedIDs.contains) {
            removable.forEach { selectedIDs.remove($0) }
        } else {
            removable.forEach { selectedIDs.insert($0) }
        }
    }

    // MARK: - Private

    private func load() async {
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

        let discovered = await service.discover()
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
        if let started = loadStartedAt {
            let elapsed = Date().timeIntervalSince(started)
            let minVisible: TimeInterval = 0.4
            if elapsed < minVisible {
                let remaining = minVisible - elapsed
                try? await Task.sleep(for: .seconds(remaining))
                guard !Task.isCancelled else { return }
            }
        }

        state = images.isEmpty ? .empty : .loaded
    }

    private func apply(_ newImages: [EmulatorImage], forceLoaded: Bool) {
        images = newImages
        // Drop selections that no longer exist (e.g. after a removal + reload).
        selectedIDs = selectedIDs.intersection(Set(newImages.map(\.id)))
        if forceLoaded {
            state = newImages.isEmpty ? .empty : .loaded
        }
    }
}
