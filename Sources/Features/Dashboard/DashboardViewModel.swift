import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let scanner: any StorageScanning
    private let permissionHandler: any StoragePermissionHandling
    private var scanTask: Task<Void, Never>?

    private(set) var phase: ScanPhase = .idle
    private(set) var progress = 0.0
    private(set) var currentLocation = ""
    private(set) var scannedItemCount = 0
    private(set) var scannerProgress: [ScannerProgress] = []
    private(set) var permissionStatuses: [StoragePermissionStatus]
    private(set) var snapshot: ScanSnapshot?
    var selectedDomain: StorageDomain?

    init(
        scanner: any StorageScanning,
        permissionHandler: any StoragePermissionHandling = FileSystemPermissionService()
    ) {
        self.scanner = scanner
        self.permissionHandler = permissionHandler
        permissionStatuses = permissionHandler.currentStatuses()
    }

    var isScanning: Bool {
        phase == .scanning
    }

    var blockedPermissions: [StoragePermissionStatus] {
        permissionStatuses.filter { $0.state == .denied }
    }

    var hasPermissionIssues: Bool {
        !blockedPermissions.isEmpty
    }

    var permissionSummary: String {
        let accessibleCount = permissionStatuses.filter { $0.state == .accessible }.count
        if let blockedStatus = permissionStatuses.first(where: { $0.state != .accessible }) {
            return "\(accessibleCount) of \(permissionStatuses.count) locations accessible; "
                + "\(blockedStatus.scope.title) needs review at \(blockedStatus.url.lastPathComponent)"
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

    private func beginScanning() {
        scanTask?.cancel()
        progress = 0
        currentLocation = "Preparing scanner…"
        scannedItemCount = 0
        scannerProgress = []
        snapshot = nil
        selectedDomain = nil
        phase = .scanning

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
            self.snapshot = snapshot
            scannedItemCount = snapshot.scannedItemCount
            progress = 1
            phase = snapshot.findings.isEmpty ? .empty : .results
            scanTask = nil
        }
    }
}
