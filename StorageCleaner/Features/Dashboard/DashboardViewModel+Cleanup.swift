import Foundation

/// A cleanup that left items behind, ready to be shown to the user. Presented
/// once, app-wide, from `AppShellView` so every delete path — not just System
/// Junk's inline flow — tells the user what failed and offers a retry.
struct CleanupFailurePrompt: Identifiable {
    /// Routes a retry back through the operation that produced the failure,
    /// so Homebrew kegs retry via `brew uninstall` and not a plain trash.
    enum RetryRoute: Sendable {
        case trash
        case cliRemoval
        case runtimeRemoval
    }

    let id = UUID()
    let feedback: CleanupFeedback
    let failedURLs: [URL]
    let route: RetryRoute
}

/// Cleanup entry points and post-cleanup reconciliation for
/// ``DashboardViewModel``. Split out so the main file stays under the
/// 620-line SwiftLint limit.
extension DashboardViewModel {
    /// Non-nil when the audit trail could not be written. Shown as a warning
    /// banner on the Cleanup History screen so silent record loss is visible.
    var historyPersistenceWarning: String? {
        historyStore?.lastPersistenceError
    }

    /// Deletes all stored scan history. Invoked from the History screen's
    /// confirmation flow; the `@Query`-driven list empties automatically.
    func clearHistory() {
        historyStore?.clearHistory()
    }

    /// Moves files to Trash and reconciles findings, audit history, and the
    /// volume snapshot. When `surfacingFailure` is `true` (the default), a
    /// partial or total failure raises `cleanupFailure` so `AppShellView`
    /// presents the app-wide failure sheet. Pass `false` only when the caller
    /// surfaces the returned `CleanupResult` itself (System Junk, Quick Clean).
    func deleteFiles(_ urls: [URL], surfacingFailure: Bool = true) async -> CleanupResult {
        guard gateCleanup() else {
            return CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [],
                totalBytesReclaimed: 0
            )
        }
        let access = permissionHandler.beginHomeFolderAccess()
        defer { access?.stop() }
        let result = await cleanupService.delete(urls: urls)
        await reconcileCleanup(result, failureRoute: surfacingFailure ? .trash : nil)
        return result
    }

    /// Properly uninstalls CLI programs (Homebrew via `brew uninstall`, others by
    /// trashing) so nothing is left abandoned, then reconciles the `cliApps` finding
    /// and records history. Returns the result so the caller can refresh its view.
    func removeCLIPrograms(_ urls: [URL]) async -> CleanupResult {
        guard gateCleanup() else {
            return CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [],
                totalBytesReclaimed: 0
            )
        }
        let result = await cliRemovalService.remove(urls)
        await reconcileCleanup(result, auditKind: .cliApps, failureRoute: .cliRemoval)
        return result
    }

    /// and reconciles the `runtimeVersions` finding. Recorded as a `.runtimeVersions`
    /// audit entry so Cleanup History reflects what was reclaimed. Returns the result
    /// so the caller can refresh its view.
    func removeRuntimeVersions(_ urls: [URL]) async -> CleanupResult {
        guard gateCleanup() else {
            return CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [],
                totalBytesReclaimed: 0
            )
        }
        let result = await cliRemovalService.remove(urls)
        await reconcileCleanup(result, auditKind: .runtimeVersions, failureRoute: .runtimeRemoval)
        return result
    }

    /// Re-runs a failed cleanup through the operation that produced it.
    func retryCleanup(_ prompt: CleanupFailurePrompt) async {
        switch prompt.route {
        case .trash:
            _ = await deleteFiles(prompt.failedURLs)
        case .cliRemoval:
            _ = await removeCLIPrograms(prompt.failedURLs)
        case .runtimeRemoval:
            _ = await removeRuntimeVersions(prompt.failedURLs)
        }
    }

    func reconcileEmulatorCleanup(
        _ result: EmulatorCleanupResult,
        removedImages images: [EmulatorImage]
    ) async {
        let removedIDs = Set(result.removedIDs)
        let removedImages = images.filter { removedIDs.contains($0.id) }
        guard !removedImages.isEmpty else { return }

        let deletedItems = removedImages.compactMap { image -> DeletedItem? in
            guard case let .trashDirectory(url) = image.removal else { return nil }
            return DeletedItem(originalURL: url, bytesReclaimed: image.bytes)
        }
        lastCleanupResult = CleanupResult(
            deletedURLs: deletedItems.map(\.originalURL),
            deletedItems: deletedItems,
            failedURLs: [],
            totalBytesReclaimed: result.totalBytesReclaimed
        )

        await refreshVolumeSnapshotAsync()
        recordEmulatorCleanupAudit(removedImages)
        pruneSnapshot(reclaimedBytesByURL: reclaimedBytesByURL(from: deletedItems))
    }

    private func reconcileCleanup(
        _ result: CleanupResult,
        auditKind: StorageFindingKind? = nil,
        failureRoute: CleanupFailurePrompt.RetryRoute? = nil
    ) async {
        lastCleanupResult = result
        // Raise the failure prompt before the empty-deletions guard: an
        // all-failed cleanup is exactly the case the user must hear about.
        if let failureRoute, result.failedCount > 0 {
            cleanupFailure = CleanupFailurePrompt(
                feedback: .failed(result: result),
                failedURLs: result.failedURLs.map(\.0),
                route: failureRoute
            )
        }
        guard !result.deletedItems.isEmpty else { return }

        // Refresh the volume snapshot *before* recording the audit, so the
        // "free bytes after" captured on `StoredScan` reflects the volume
        // state once the trashed items are gone. The refresh dispatches a
        // background task; awaiting it here keeps the audit recording in
        // lockstep with the post-cleanup free-bytes value.
        await refreshVolumeSnapshotAsync()

        let reclaimedBytesByURL = reclaimedBytesByURL(from: result.deletedItems)
        if let auditKind {
            historyStore?.recordCleanupActions([
                CleanupAuditEntry(
                    kind: auditKind,
                    bytesReclaimed: result.totalBytesReclaimed,
                    itemCount: result.deletedCount,
                    samplePaths: CleanupAuditRecorder.samplePaths(
                        from: result.deletedItems.map(\.originalURL)
                    )
                )
            ], disk: currentScanDiskSnapshot())
        } else {
            recordCleanupAudit(reclaimedBytesByURL: reclaimedBytesByURL)
        }

        pruneSnapshot(reclaimedBytesByURL: reclaimedBytesByURL)
    }

    private func reclaimedBytesByURL(from deletedItems: [DeletedItem]) -> [URL: Int64] {
        Dictionary(
            deletedItems.map { ($0.originalURL, $0.bytesReclaimed) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func pruneSnapshot(reclaimedBytesByURL: [URL: Int64]) {
        guard let currentSnapshot = snapshot, !reclaimedBytesByURL.isEmpty else { return }
        let updatedFindings = currentSnapshot.findings.compactMap { finding in
            pruneDeletedPaths(from: finding, reclaimedBytesByURL: reclaimedBytesByURL)
        }
        snapshot = ScanSnapshot(
            findings: updatedFindings,
            scannedItemCount: currentSnapshot.scannedItemCount,
            duration: currentSnapshot.duration
        )
    }

    private func recordEmulatorCleanupAudit(_ images: [EmulatorImage]) {
        guard let historyStore else { return }
        let grouped = Dictionary(grouping: images) { image in
            emulatorStorageKind(for: image)
        }
        let entries = grouped.keys.sorted { $0.rawValue < $1.rawValue }.map { kind in
            let images = grouped[kind, default: []]
            let samplePaths = images.compactMap(\.trashDirectoryURL)
            return CleanupAuditEntry(
                kind: kind,
                bytesReclaimed: images.reduce(0) { $0 + $1.bytes },
                itemCount: images.count,
                samplePaths: CleanupAuditRecorder.samplePaths(from: samplePaths)
            )
        }
        historyStore.recordCleanupActions(entries, disk: currentScanDiskSnapshot())
    }

    private func emulatorStorageKind(for image: EmulatorImage) -> StorageFindingKind {
        switch image.platform {
        case .appleSimulator, .simulatorDevices:
            .xcodeArtifacts
        case .iosDeviceSupport:
            .iosDeviceSupport
        case .androidEmulator:
            .androidStudioArtifacts
        }
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

        // Set-based membership keeps this O(paths) — `matchesFilesystemURL`
        // is normalized-path equality, so a Set of normalized paths is exact.
        let deletedPaths = Set(reclaimedBytesByURL.keys.map(\.normalizedFilesystemPath))
        let remainingPaths = finding.filePaths.filter { scannedURL in
            !deletedPaths.contains(scannedURL.normalizedFilesystemPath)
        }
        guard !remainingPaths.isEmpty else { return nil }

        let reclaimedBytes = reclaimedBytesByURL.reduce(Int64(0)) { total, entry in
            finding.contains(entry.key) ? total + entry.value : total
        }
        guard reclaimedBytes > 0 || remainingPaths.count != finding.filePaths.count else { return finding }

        let updatedBytes = max(0, finding.bytes - reclaimedBytes)
        guard updatedBytes > 0 else { return nil }

        let remainingSet = Set(remainingPaths.map(\.normalizedFilesystemPath))
        return StorageFinding(
            kind: finding.kind,
            domain: finding.domain,
            bytes: updatedBytes,
            itemCount: remainingPaths.count,
            safety: finding.safety,
            examples: finding.examples,
            filePaths: remainingPaths,
            pathBytes: finding.pathBytes.filter { path, _ in
                remainingSet.contains(path.normalizedFilesystemPath)
            }
        )
    }

    /// Records one audit entry per affected category so cleanup history reflects what was
    /// removed. See `DashboardViewModel+CleanupAudit.swift` for the attribution rules
    /// (snapshot-first, `CleanupOption` fallback, `.junkFiles` last resort).
    private func recordCleanupAudit(reclaimedBytesByURL: [URL: Int64]) {
        CleanupAuditRecorder.record(
            reclaimedBytesByURL: reclaimedBytesByURL,
            snapshot: snapshot,
            historyStore: historyStore,
            disk: currentScanDiskSnapshot()
        )
    }
}
