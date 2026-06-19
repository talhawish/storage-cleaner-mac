import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    private let scanner: any StorageScanning
    private let permissionHandler: any StoragePermissionHandling
    private let cleanupService: CleanupService
    private let cliRemovalService: CLIRemovalService
    private let historyStore: (any ScanHistoryStore)?
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
    private(set) var snapshot: ScanSnapshot?
    private(set) var lastCleanupResult: CleanupResult?
    /// Domains whose newest sampled files are older than the stale threshold. Populated off the main
    /// thread after a scan completes; empty until (and unless) sampling finds something.
    private(set) var staleHints: [StaleHint] = []
    private var staleTask: Task<Void, Never>?
    var selectedDomain: StorageDomain?
    var selectedFinding: StorageFinding?

    init(
        scanner: any StorageScanning,
        permissionHandler: any StoragePermissionHandling = FileSystemPermissionService(),
        cleanupService: CleanupService = FileManagerCleanupService(),
        cliRemovalService: CLIRemovalService = .live,
        historyStore: (any ScanHistoryStore)? = nil
    ) {
        self.scanner = scanner
        self.permissionHandler = permissionHandler
        self.cleanupService = cleanupService
        self.cliRemovalService = cliRemovalService
        self.historyStore = historyStore
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

        guard !hasPermissionIssues else {
            phase = .permissionRequired
            return
        }

        beginScanning(for: pendingScanKinds)
    }

    func retryAfterPermission() {
        permissionStatuses = permissionHandler.currentStatuses()

        guard !hasPermissionIssues else {
            return
        }

        beginScanning(for: pendingScanKinds)
    }

    func openSystemSettings() {
        guard let url = SystemSettingsPane.fullDiskAccess.url else { return }
        NSWorkspace.shared.open(url)
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        staleTask?.cancel()
        progress = 0
        currentLocation = ""
        scannedItemCount = 0
        scannerProgress = []
        phase = .idle
    }

    func deleteFiles(_ urls: [URL]) async -> CleanupResult {
        let result = await cleanupService.delete(urls: urls)
        lastCleanupResult = result

        // `deletedItems` is keyed by the *original* path with the bytes captured at delete time;
        // `result.deletedURLs` holds Trash locations and cannot be matched against findings.
        let reclaimedBytesByURL = Dictionary(
            result.deletedItems.map { ($0.originalURL, $0.bytesReclaimed) },
            uniquingKeysWith: { first, _ in first }
        )

        recordCleanupAudit(reclaimedBytesByURL: reclaimedBytesByURL)

        if let currentSnapshot = snapshot {
            let updatedFindings = currentSnapshot.findings.compactMap { finding in
                pruneDeletedPaths(from: finding, reclaimedBytesByURL: reclaimedBytesByURL)
            }
            snapshot = ScanSnapshot(
                findings: updatedFindings,
                scannedItemCount: currentSnapshot.scannedItemCount,
                duration: currentSnapshot.duration
            )
        }

        return result
    }

    /// Properly uninstalls CLI programs (Homebrew via `brew uninstall`, others by
    /// trashing) so nothing is left abandoned, then reconciles the `cliApps` finding
    /// and records history. Returns the result so the caller can refresh its view.
    func removeCLIPrograms(_ urls: [URL]) async -> CleanupResult {
        let result = await cliRemovalService.remove(urls)
        lastCleanupResult = result

        guard result.totalBytesReclaimed > 0 else { return result }

        historyStore?.recordCleanupActions([
            CleanupAuditEntry(
                kind: .cliApps,
                bytesReclaimed: result.totalBytesReclaimed,
                itemCount: result.deletedCount
            )
        ])

        if let currentSnapshot = snapshot {
            let updatedFindings = currentSnapshot.findings.map { finding -> StorageFinding in
                guard finding.kind == .cliApps else { return finding }
                return StorageFinding(
                    kind: finding.kind,
                    domain: finding.domain,
                    bytes: max(0, finding.bytes - result.totalBytesReclaimed),
                    itemCount: finding.itemCount,
                    safety: finding.safety,
                    examples: finding.examples,
                    filePaths: finding.filePaths
                )
            }
            snapshot = ScanSnapshot(
                findings: updatedFindings,
                scannedItemCount: currentSnapshot.scannedItemCount,
                duration: currentSnapshot.duration
            )
        }

        return result
    }

    /// Removes the deleted paths from a finding and decrements its byte total using the sizes
    /// captured at delete time, avoiding any synchronous filesystem access on the main actor.
    /// Returns `nil` when the finding has no remaining paths.
    private func pruneDeletedPaths(
        from finding: StorageFinding,
        reclaimedBytesByURL: [URL: Int64]
    ) -> StorageFinding? {
        // Duplicate findings are rebuilt from their (pruned) groups so deletions of any copy —
        // including a re-elected keep copy that never appears in `filePaths` — stay consistent.
        if !finding.duplicateGroups.isEmpty {
            return prunedDuplicateFinding(from: finding, deletedURLs: reclaimedBytesByURL)
        }

        let remainingPaths = finding.filePaths.filter { scannedURL in
            !reclaimedBytesByURL.keys.contains { deletedURL in
                deletedURL == scannedURL
            }
        }
        guard !remainingPaths.isEmpty else { return nil }

        let reclaimedBytes = reclaimedBytesByURL.reduce(Int64(0)) { total, entry in
            finding.contains(entry.key) ? total + entry.value : total
        }
        guard reclaimedBytes > 0 || remainingPaths.count != finding.filePaths.count else { return finding }

        let updatedBytes = max(0, finding.bytes - reclaimedBytes)
        guard updatedBytes > 0 else { return nil }

        return StorageFinding(
            kind: finding.kind,
            domain: finding.domain,
            bytes: updatedBytes,
            itemCount: remainingPaths.count,
            safety: finding.safety,
            examples: finding.examples,
            filePaths: remainingPaths
        )
    }

    /// Records one audit entry per affected category so cleanup history reflects what was removed.
    private func recordCleanupAudit(reclaimedBytesByURL: [URL: Int64]) {
        guard let historyStore, !reclaimedBytesByURL.isEmpty, let snapshot else { return }

        let entries = snapshot.findings.compactMap { finding -> CleanupAuditEntry? in
            let deletedPaths = reclaimedBytesByURL.keys.filter { finding.contains($0) }
            guard !deletedPaths.isEmpty else { return nil }
            let bytes = deletedPaths.reduce(Int64(0)) { $0 + (reclaimedBytesByURL[$1] ?? 0) }
            return CleanupAuditEntry(kind: finding.kind, bytesReclaimed: bytes, itemCount: deletedPaths.count)
        }
        historyStore.recordCleanupActions(entries)
    }

    private func beginScanning(for kinds: Set<StorageFindingKind>?) {
        scanTask?.cancel()
        progress = 0
        currentLocation = "Preparing scanner…"
        scannedItemCount = 0
        scannerProgress = []
        activeScanKinds = kinds
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
            for await event in scanner.scanEvents(for: kinds) {
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
            let mergedFindings = mergeFindings(from: snapshot)
            let adjustedSnapshot = ScanSnapshot(
                findings: mergedFindings,
                scannedItemCount: snapshot.scannedItemCount,
                duration: duration
            )
            self.snapshot = adjustedSnapshot
            scannedItemCount = adjustedSnapshot.scannedItemCount
            progress = 1
            phase = adjustedSnapshot.findings.isEmpty ? .empty : .results
            refreshStaleHints()
            // Only full scans become history records; targeted re-scans refresh a subset in place.
            if activeScanKinds == nil {
                historyStore?.recordCompletedScan(adjustedSnapshot)
            }
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

// MARK: - Overview aggregation

extension DashboardViewModel {
    /// Top domains for the Overview breakdown grid, with the long tail folded into "Other".
    var domainTiles: [StorageOverview.DomainUsage] {
        StorageOverview.tiles(in: snapshot?.findings ?? [], maxTiles: 6)
    }

    /// Every present domain rolled up, backing the grouped detection rows.
    var domainGroups: [StorageOverview.DomainUsage] {
        StorageOverview.domainUsages(in: snapshot?.findings ?? [])
    }

    var safeReclaimableBytes: Int64 {
        StorageOverview.safeBytes(in: snapshot?.findings ?? [])
    }

    var reviewReclaimableBytes: Int64 {
        StorageOverview.reviewBytes(in: snapshot?.findings ?? [])
    }

    var overviewTips: [OverviewTip] {
        guard let snapshot else { return [] }
        return OverviewTipBuilder.tips(for: snapshot, stale: staleHints)
    }

    /// The current finding for a kind, used to navigate from a tip or breakdown tile.
    func finding(for kind: StorageFindingKind) -> StorageFinding? {
        snapshot?.findings.first { $0.kind == kind }
    }

    /// Best-effort stale detection: samples a few paths per developer-storage finding off the main
    /// thread and flags domains whose newest sampled file is older than the threshold. Degrades
    /// silently — if sampling finds nothing, the stale tip simply never appears.
    func refreshStaleHints() {
        staleTask?.cancel()
        let samples = (snapshot?.findings ?? [])
            .filter { DeveloperDomains.kinds.contains($0.kind) && $0.bytes > 0 && !$0.filePaths.isEmpty }
            .map {
                StaleSample(
                    kind: $0.kind,
                    domain: $0.domain,
                    bytes: $0.bytes,
                    paths: Array($0.filePaths.prefix(3))
                )
            }

        guard !samples.isEmpty else {
            staleHints = []
            return
        }

        staleTask = Task { [weak self] in
            let hints = await Self.computeStaleHints(from: samples)
            guard !Task.isCancelled else { return }
            self?.staleHints = hints
        }
    }

    /// Inputs for stale sampling, captured up front so the background work touches no view-model state.
    private struct StaleSample: Sendable {
        let kind: StorageFindingKind
        let domain: StorageDomain
        let bytes: Int64
        let paths: [URL]
    }

    private static func computeStaleHints(from samples: [StaleSample]) async -> [StaleHint] {
        await Task.detached(priority: .utility) {
            let now = Date()
            return samples.compactMap { sample -> StaleHint? in
                let newest = sample.paths
                    .map { StorageFormatting.modificationDate(at: $0) }
                    .max() ?? .distantPast
                let days = Calendar.current.dateComponents([.day], from: newest, to: now).day ?? 0
                guard days >= OverviewTipBuilder.staleThresholdDays else { return nil }
                return StaleHint(
                    kind: sample.kind,
                    domain: sample.domain,
                    bytes: sample.bytes,
                    daysSinceModified: days
                )
            }
        }.value
    }
}

private extension StorageFinding {
    func contains(_ url: URL) -> Bool {
        trackedURLs.contains { scannedURL in
            scannedURL == url || scannedURL.isAncestor(of: url)
        }
    }
}

private extension URL {
    func isAncestor(of descendant: URL) -> Bool {
        let ancestorPath = standardizedFileURL.path
        let descendantPath = descendant.standardizedFileURL.path
        guard descendantPath.hasPrefix(ancestorPath) else { return false }
        let remainder = descendantPath.dropFirst(ancestorPath.count)
        return remainder.first == "/"
    }
}

// MARK: - Duplicate finding pruning

extension DashboardViewModel {
    /// Rebuilds a duplicate finding from its pruned groups. Returns `nil` when no group still has
    /// 2+ copies (nothing left to clean up).
    func prunedDuplicateFinding(
        from finding: StorageFinding,
        deletedURLs: [URL: Int64]
    ) -> StorageFinding? {
        let groups = prunedGroups(from: finding.duplicateGroups, deletedURLs: deletedURLs)
        guard !groups.isEmpty else { return nil }

        let removableURLs = groups.flatMap(\.removableURLs)
        let bytes = groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
        return StorageFinding(
            kind: finding.kind,
            domain: finding.domain,
            bytes: bytes,
            itemCount: removableURLs.count,
            safety: finding.safety,
            examples: Array(removableURLs.prefix(3).map(\.lastPathComponent)),
            filePaths: removableURLs,
            duplicateGroups: groups
        )
    }

    /// Removes deleted copies from each duplicate group, drops groups that no longer have 2+ copies,
    /// and re-elects a copy to keep when the previously kept file was the one deleted.
    private func prunedGroups(
        from groups: [DuplicateGroup],
        deletedURLs: [URL: Int64]
    ) -> [DuplicateGroup] {
        groups.compactMap { group in
            let remainingFiles = group.files.filter { deletedURLs[$0.url] == nil }
            guard remainingFiles.count > 1 else { return nil }

            let keepURL = remainingFiles.contains(where: { $0.url == group.keepURL })
                ? group.keepURL
                : DuplicateKeepStrategy.bestToKeep(from: remainingFiles).url
            return DuplicateGroup(contentHash: group.contentHash, files: remainingFiles, keepURL: keepURL)
        }
    }
}
