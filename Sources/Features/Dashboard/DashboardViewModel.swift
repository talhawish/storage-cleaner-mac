import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let scanner: any StorageScanning
    private let permissionHandler: any StoragePermissionHandling
    private let cleanupService: CleanupService
    private var scanTask: Task<Void, Never>?
    private var scanStartTime: Date?

    private(set) var phase: ScanPhase = .idle
    private(set) var progress = 0.0
    private(set) var currentLocation = ""
    private(set) var scannedItemCount = 0
    private(set) var scannerProgress: [ScannerProgress] = []
    private(set) var permissionStatuses: [StoragePermissionStatus]
    private(set) var snapshot: ScanSnapshot?
    private(set) var lastCleanupResult: CleanupResult?
    var selectedDomain: StorageDomain?
    var selectedFinding: StorageFinding?

    init(
        scanner: any StorageScanning,
        permissionHandler: any StoragePermissionHandling = FileSystemPermissionService(),
        cleanupService: CleanupService = FileManagerCleanupService()
    ) {
        self.scanner = scanner
        self.permissionHandler = permissionHandler
        self.cleanupService = cleanupService
        permissionStatuses = permissionHandler.currentStatuses()
    }

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
        if let blockedStatus = permissionStatuses.first(where: { $0.state != .accessible && $0.scope.isBlocking }) {
            return "\(accessibleCount) of \(permissionStatuses.count) locations accessible; "
                + "\(blockedStatus.scope.title) needs review at \(blockedStatus.url.lastPathComponent)"
        }

        let warningCount = warningPermissions.count
        if warningCount > 0 {
            let locationWord = warningCount == 1 ? "location" : "locations"
            let needWord = warningCount == 1 ? "needs" : "need"
            return "\(accessibleCount) of \(permissionStatuses.count) locations accessible; "
                + "\(warningCount) \(locationWord) \(needWord) Full Disk Access"
        }

        return "All \(permissionStatuses.count) storage locations accessible"
    }

    func startScan() {
        guard !isScanning else { return }

        permissionStatuses = permissionHandler.currentStatuses()

        guard !hasPermissionIssues else {
            phase = .permissionRequired
            return
        }

        beginScanning()
    }

    func retryAfterPermission() {
        permissionStatuses = permissionHandler.currentStatuses()

        guard !hasPermissionIssues else {
            return
        }

        beginScanning()
    }

    func openSystemSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        progress = 0
        currentLocation = ""
        scannedItemCount = 0
        scannerProgress = []
        phase = .idle
    }

    func deleteFiles(_ urls: [URL]) async -> CleanupResult {
        let result = await cleanupService.delete(urls: urls)
        lastCleanupResult = result

        if var currentSnapshot = snapshot {
            let deletedSet = Set(result.deletedURLs)
            let updatedFindings = currentSnapshot.findings.compactMap { finding -> StorageFinding? in
                let remainingPaths = finding.filePaths.filter { !deletedSet.contains($0) }
                guard !remainingPaths.isEmpty else { return nil }
                let remainingBytes = remainingPaths.reduce(Int64(0)) { total, url in
                    total + StorageFormatting.fileSize(at: url)
                }
                return StorageFinding(
                    kind: finding.kind,
                    domain: finding.domain,
                    bytes: remainingBytes,
                    itemCount: remainingPaths.count,
                    safety: finding.safety,
                    examples: finding.examples,
                    filePaths: remainingPaths
                )
            }
            currentSnapshot = ScanSnapshot(
                findings: updatedFindings,
                scannedItemCount: currentSnapshot.scannedItemCount,
                duration: currentSnapshot.duration
            )
            snapshot = currentSnapshot
        }

        return result
    }

    private func beginScanning() {
        scanTask?.cancel()
        progress = 0
        currentLocation = "Preparing scanner…"
        scannedItemCount = 0
        scannerProgress = []
        snapshot = nil
        selectedDomain = nil
        selectedFinding = nil
        phase = .scanning
        scanStartTime = .now

        let scanner = scanner
        scanTask = Task { [weak self] in
            for await event in scanner.scanEvents() {
                guard !Task.isCancelled else { return }
                self?.consume(event)
            }
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
            let adjustedSnapshot = ScanSnapshot(
                findings: snapshot.findings,
                scannedItemCount: snapshot.scannedItemCount,
                duration: duration
            )
            self.snapshot = adjustedSnapshot
            scannedItemCount = adjustedSnapshot.scannedItemCount
            progress = 1
            phase = adjustedSnapshot.findings.isEmpty ? .empty : .results
            scanTask = nil
        }
    }
}
