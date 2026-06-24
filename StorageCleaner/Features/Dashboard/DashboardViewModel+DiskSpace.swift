import Foundation

/// Disk-space tracking owned by ``DashboardViewModel``. Captures the volume
/// snapshot at scan time, refreshes it after each cleanup, and exposes the
/// "free now / after cleanup" projections the home screen renders. Lives in
/// its own file to keep ``DashboardViewModel`` under the 620-line SwiftLint
/// limit.
extension DashboardViewModel {
    /// Total reclaimable bytes (`safe + review`) for the current snapshot. Used
    /// to render the "you could reclaim X" call-out on the storage status card.
    var totalReclaimableBytes: Int64 {
        safeReclaimableBytes + reviewReclaimableBytes
    }

    /// Free-bytes projection for the home screen's storage card once the
    /// current snapshot's findings are reclaimed. `nil` when the volume
    /// attributes are unavailable so the view can fall back to a hidden state.
    var projectedFreeBytes: Int64? {
        guard volumeSnapshot.isAvailable else { return nil }
        return volumeSnapshot.projectedFreeBytes(reclaiming: totalReclaimableBytes)
    }

    /// Projected usage fraction once the current snapshot is reclaimed.
    /// `nil` when the volume attributes are unavailable.
    var projectedUsageFraction: Double? {
        guard volumeSnapshot.isAvailable else { return nil }
        return volumeSnapshot.projectedUsageFraction(reclaiming: totalReclaimableBytes)
    }

    /// Re-reads the volume attributes off the main actor and publishes the
    /// result. Cancellable so a scan-completed refresh and a user-initiated
    /// refresh never overlap.
    func refreshVolumeSnapshot() {
        diskSpaceTask?.cancel()
        let reader = diskSpaceReader
        let path = UserHomeDirectory.url
        diskSpaceTask = Task { [weak self] in
            let snapshot = await reader.currentVolume(at: path)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.volumeSnapshot = snapshot
            }
        }
    }

    /// Awaits the next volume refresh and returns the resulting snapshot.
    /// Used by `deleteFiles` and the CLI/runtime cleanup paths so the audit
    /// records a "free bytes after" value that reflects the actual post-cleanup
    /// volume state. Safe to call from `@MainActor` methods; the underlying
    /// read still happens off the main thread.
    @discardableResult
    func refreshVolumeSnapshotAsync() async -> VolumeSnapshot {
        let reader = diskSpaceReader
        let path = UserHomeDirectory.url
        let snapshot = await reader.currentVolume(at: path)
        volumeSnapshot = snapshot
        return snapshot
    }

    /// Converts the current `volumeSnapshot` (kept fresh by the disk reader) into the
    /// `ScanDiskSnapshot` shape the history store expects. Falls back to the last
    /// known free bytes when a refresh is in flight and the cached snapshot is
    /// `0`-bytes only because the call hasn't returned yet.
    func currentScanDiskSnapshot() -> ScanDiskSnapshot {
        if volumeSnapshot.isAvailable {
            return ScanDiskSnapshot(
                totalBytes: volumeSnapshot.totalBytes,
                freeBytes: volumeSnapshot.freeBytes
            )
        }
        return .unavailable
    }
}
