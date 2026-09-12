import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let scanner: any StorageScanning
    /// Exposed so dependent features (Quick Clean) can reuse the same
    /// security-scoped access grant instead of requesting their own. Kept
    /// `internal` (not `private`) for that one call site; treat as
    /// read-only.
    let permissionHandler: any StoragePermissionHandling
    /// `internal` (not `private`) so the cleanup extension in
    /// `DashboardViewModel+Cleanup.swift` can reach them; treat all three
    /// as read-only outside that file.
    let cleanupService: CleanupService
    let cliRemovalService: CLIRemovalService
    let dockerService: DockerService
    let emulatorService: any EmulatorsServicing
    let historyStore: (any ScanHistoryStore)?
    /// Owns the app's current Pro/Free entitlement. Optional so existing
    /// unit tests that don't care about subscriptions can still construct
    /// the VM. When `nil`, the cleanup gate is open (legacy behavior)
    /// — production wiring in `StorageCleanerApp` always passes one in.
    /// `internal` (not `private`) so the `+Subscription` extension file
    /// can read it; the reference is read-only by convention.
    let subscriptionController: SubscriptionController?
    private var scanTask: Task<Void, Never>?
    private var scanStartTime: Date?
    private var pendingScanKinds: Set<StorageFindingKind>?
    private var activeScanKinds: Set<StorageFindingKind>?

    private(set) var phase: ScanPhase = .idle
    private(set) var progress = 0.0
    private(set) var currentLocation = ""
    private(set) var scannedItemCount = 0
    private(set) var scannerProgress: [ScannerProgress] = []
    private(set) var permissionStatuses: [StoragePermissionStatus]
    /// Setters are `internal` so `DashboardViewModel+Cleanup.swift` can
    /// reconcile findings after a delete; other files treat them as read-only.
    var snapshot: ScanSnapshot?
    var lastCleanupResult: CleanupResult?
    /// Set when a cleanup leaves items behind and no feature-local flow is
    /// showing the failure. `AppShellView` presents it as a single app-wide
    /// sheet with a retry action; views clear it (or the sheet's dismiss does).
    var cleanupFailure: CleanupFailurePrompt?
    /// Latest disk-space snapshot for the startup volume. Refreshed on init,
    /// after every scan completes, and after every successful cleanup. Drives
    /// the home screen "Storage Status" card and the Quick Clean success
    /// view's "free space after" pill.
    var volumeSnapshot: VolumeSnapshot = .unavailable
    /// Free bytes captured the moment a scan started. Combined with
    /// `volumeSnapshot` it powers the "free before / after" pill on the
    /// Cleanup History card. Reset to `nil` when no scan is in flight.
    private(set) var freeBytesAtScanStart: Int64?
    /// Domains whose newest sampled files are older than the stale threshold. Populated off the main
    /// thread after a scan completes; empty until (and unless) sampling finds something.
    /// Setter is `internal` (the default — explicit modifier would
    /// be redundant) so the overview extension in
    /// `DashboardViewModel+Overview.swift` can populate it from a
    /// detached task. Reads are still module-internal.
    var staleHints: [StaleHint] = []
    /// What the most recent scan covered. `never` means no scan has
    /// completed in this session (so every section is in its pre-scan
    /// "ready to discover" state). `full` means a full scan ran and covered
    /// every kind. `targeted` means only the listed kinds were scanned, so
    /// other sections should still show their pre-scan state until they
    /// too are scanned.
    private(set) var lastCompletedScan: LastScan = .never
    var staleTask: Task<Void, Never>?
    var diskSpaceTask: Task<Void, Never>?
    let diskSpaceReader: any DiskSpaceReading
    var selectedDomain: StorageDomain?
    var selectedFinding: StorageFinding?

    init(
        scanner: any StorageScanning,
        permissionHandler: any StoragePermissionHandling = FileSystemPermissionService(),
        cleanupService: CleanupService = FileManagerCleanupService(),
        cliRemovalService: CLIRemovalService = .live,
        dockerService: DockerService = .live,
        emulatorService: any EmulatorsServicing = EmulatorManagementService.live,
        diskSpaceReader: any DiskSpaceReading = LiveDiskSpaceService.shared,
        historyStore: (any ScanHistoryStore)? = nil,
        subscriptionController: SubscriptionController? = nil
    ) {
        self.scanner = scanner
        self.permissionHandler = permissionHandler
        self.cleanupService = cleanupService
        self.cliRemovalService = cliRemovalService
        self.dockerService = dockerService
        self.emulatorService = emulatorService
        self.diskSpaceReader = diskSpaceReader
        self.historyStore = historyStore
        self.subscriptionController = subscriptionController
        permissionStatuses = permissionHandler.currentStatuses()
        refreshVolumeSnapshot()
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        staleTask?.cancel()
        progress = 0
        currentLocation = ""
        scannedItemCount = 0
        scannerProgress = []
        activeScanKinds = nil
        freeBytesAtScanStart = nil

        if let snapshot, !snapshot.findings.isEmpty {
            phase = .results
        } else if snapshot != nil {
            phase = .empty
        } else {
            phase = .idle
        }
    }

    private func beginScanning(for kinds: Set<StorageFindingKind>?) {
        scanTask?.cancel()
        progress = 0
        currentLocation = "Preparing scanner…"
        scannedItemCount = 0
        scannerProgress = []
        activeScanKinds = kinds
        freeBytesAtScanStart = volumeSnapshot.isAvailable ? volumeSnapshot.freeBytes : 0
        if kinds == nil {
            snapshot = nil
            selectedDomain = nil
            selectedFinding = nil
            staleTask?.cancel()
            staleHints = []
        }
        phase = .scanning
        scanStartTime = .now

        let scanner = scanner
        scanTask = Task { [weak self] in
            var didFinish = false
            for await event in scanner.scanEvents(for: kinds) {
                guard !Task.isCancelled else { return }
                if case .completed = event {
                    didFinish = true
                } else if case .failed = event {
                    didFinish = true
                }
                self?.consume(event)
            }
            await MainActor.run {
                guard let self, self.phase == .scanning else { return }
                guard !didFinish else { return }
                self.phase = .failed(message: "The scan stopped before it completed. Try scanning again.")
                self.scanTask = nil
                self.activeScanKinds = nil
            }
        }
    }

    func hasScanned(_ kinds: [StorageFindingKind]) -> Bool {
        guard !kinds.isEmpty else { return false }
        switch lastCompletedScan {
        case .never:
            return false
        case .full:
            return true
        case let .targeted(scanned):
            return Set(kinds).isSubset(of: scanned)
        }
    }

    private func consume(_ event: ScanEvent) {
        switch event {
        case let .progress(fraction, location, itemCount, scannerProgress):
            progress = min(max(fraction, 0), 1)
            currentLocation = location
            scannedItemCount = itemCount
            self.scannerProgress = scannerProgress
        case let .completed(snapshot):
            let duration: Duration
            if let startTime = scanStartTime {
                duration = .seconds(abs(startTime.timeIntervalSinceNow))
            } else {
                duration = snapshot.duration
            }
            let mergedFindings = mergeFindings(from: snapshot)
            let adjustedSnapshot = ScanSnapshot(
                findings: mergedFindings,
                scannedItemCount: snapshot.scannedItemCount,
                duration: duration
            )
            self.snapshot = adjustedSnapshot
            scannedItemCount = adjustedSnapshot.scannedItemCount
            progress = 1
            if let activeScanKinds {
                if lastCompletedScan != .full {
                    lastCompletedScan = .targeted(activeScanKinds)
                }
            } else {
                lastCompletedScan = .full
            }
            phase = adjustedSnapshot.findings.isEmpty ? .empty : .results
            refreshStaleHints()
            refreshVolumeSnapshot()
            // Only full scans become history records; targeted re-scans refresh a subset in place.
            if activeScanKinds == nil {
                let disk = ScanDiskSnapshot(
                    totalBytes: volumeSnapshot.totalBytes,
                    freeBytes: freeBytesAtScanStart ?? volumeSnapshot.freeBytes
                )
                historyStore?.recordCompletedScan(adjustedSnapshot, disk: disk)
            }
            freeBytesAtScanStart = nil
            scanTask = nil
            activeScanKinds = nil
        case let .failed(message):
            phase = .failed(message: message)
            scanTask = nil
            activeScanKinds = nil
        }
    }

    private func mergeFindings(from completedSnapshot: ScanSnapshot) -> [StorageFinding] {
        guard let activeScanKinds, let existingSnapshot = snapshot else {
            return completedSnapshot.findings
        }

        let preservedFindings = existingSnapshot.findings.filter { !activeScanKinds.contains($0.kind) }
        return preservedFindings + completedSnapshot.findings
    }
}

// MARK: - Scan controls and permissions

extension DashboardViewModel {
    var isScanning: Bool {
        phase == .scanning
    }

    var blockedPermissions: [StoragePermissionStatus] {
        permissionStatuses.filter { $0.state == .denied && $0.scope.isBlocking }
    }

    var hasPermissionIssues: Bool {
        !blockedPermissions.isEmpty
    }

    var warningPermissions: [StoragePermissionStatus] {
        permissionStatuses.filter { $0.state == .denied && !$0.scope.isBlocking }
    }

    var permissionSummary: String {
        let accessibleCount = permissionStatuses.filter { $0.state == .accessible }.count
        if let blockedStatus = permissionStatuses.first(where: { $0.state == .denied && $0.scope.isBlocking }) {
            return "\(blockedStatus.scope.title) access required; choose \(blockedStatus.url.path)"
        }

        let warningCount = warningPermissions.count
        if warningCount > 0 {
            let locationWord = warningCount == 1 ? "location" : "locations"
            let needWord = warningCount == 1 ? "needs" : "need"
            return "\(accessibleCount) of \(permissionStatuses.count) locations accessible; "
                + "\(warningCount) \(locationWord) \(needWord) Full Disk Access"
        }

        return "Home Folder access ready"
    }

    func startScan() {
        startScan(kinds: nil)
    }

    func startScan(for kinds: [StorageFindingKind]) {
        startScan(kinds: kinds)
    }

    private func startScan(kinds: [StorageFindingKind]?) {
        guard !isScanning else { return }
        pendingScanKinds = kinds.map(Set.init)
        selectedFinding = nil

        permissionStatuses = permissionHandler.currentStatuses()

        guard ensureAccessAvailable() else {
            // Either `currentStatuses()` reported a missing/denied scope
            // (caught by `hasPermissionIssues`) or the saved bookmark
            // couldn't be resolved into a live access token (stale
            // bookmark, revoked permission). Either way the user needs
            // to re-grant Home Folder access before the scan can run.
            phase = .permissionRequired
            return
        }

        beginScanning(for: pendingScanKinds)
    }

    func retryAfterPermission() {
        permissionStatuses = permissionHandler.currentStatuses()

        if hasPermissionIssues {
            _ = permissionHandler.requestHomeFolderAccess()
            permissionStatuses = permissionHandler.currentStatuses()
        }

        guard ensureAccessAvailable() else {
            // Still no usable access even after prompting — the saved
            // bookmark may be stale. Surface the guide so the user can
            // re-grant instead of seeing a generic "retry" failure.
            phase = .permissionRequired
            return
        }

        beginScanning(for: pendingScanKinds)
    }

    /// Probes the permission handler's access token instead of trusting
    /// the cached `permissionStatuses` alone. `currentStatuses()` reports
    /// `.accessible` whenever a bookmark is on disk, but a bookmark can
    /// outlive the user's grant (e.g. the user revoked Home Folder
    /// access in System Settings without re-prompting). `beginHomeFolderAccess()`
    /// is the only call that actually starts the security scope and is
    /// therefore the single source of truth for "can the next scan run?".
    ///
    /// Returns `false` when the access probe fails; callers transition
    /// to `.permissionRequired` so the user sees the permission guide
    /// (`PermissionRequiredView`) instead of a generic `ErrorStateView`
    /// from a downstream `.failed` scan event.
    private func ensureAccessAvailable() -> Bool {
        guard let access = permissionHandler.beginHomeFolderAccess() else {
            return false
        }
        access.stop()
        return true
    }

    func grantHomeFolderAccess() {
        retryAfterPermission()
    }

    func openSystemSettings() {
        guard let url = SystemSettingsPane.fullDiskAccess.url else { return }
        NSWorkspace.shared.open(url)
    }
}
