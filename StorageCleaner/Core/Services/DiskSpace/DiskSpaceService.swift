import Foundation

/// Reads the user's startup volume capacity on demand. Cheap to call (it just
/// queries cached `URLResourceKey` values), so the dashboard refreshes the
/// snapshot every time it re-appears and after each cleanup. Off the main
/// actor — implementations are `Sendable` so the call can be awaited from any
/// `Task`.
protocol DiskSpaceReading: Sendable {
    /// Returns the current `VolumeSnapshot` for the volume that contains
    /// `path`. Defaults to the volume that contains the user's home
    /// directory, which is almost always the startup disk on macOS.
    func currentVolume(at path: URL) async -> VolumeSnapshot
}

/// Real `DiskSpaceReading` backed by `FileManager`'s cached volume
/// attributes. Wrapped in an `actor` so multiple refreshes can be in flight
/// without duplicating work, and the values come straight from the kernel via
/// the `URLResourceKey` cache — no `statfs` calls or `df` parsing.
actor LiveDiskSpaceService: DiskSpaceReading {
    static let shared = LiveDiskSpaceService()

    func currentVolume(at path: URL) async -> VolumeSnapshot {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]
        guard let values = try? path.resourceValues(forKeys: keys) else {
            return .unavailable
        }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        // Prefer the "for important usage" value when present — it matches the
        // number macOS shows in About This Mac, so the UI tells the same story
        // as the system. Fall back to the generic available capacity. The two
        // resource keys report different integer types (`Int64` and `Int`
        // respectively) so the conversion is done explicitly.
        let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage ?? 0
        let generic = Int64(values.volumeAvailableCapacity ?? 0)
        let freeSource = opportunistic > 0 ? opportunistic : generic
        let used = max(0, total - freeSource)
        return VolumeSnapshot(totalBytes: total, usedBytes: used, freeBytes: freeSource)
    }
}

/// In-memory disk space provider used by the demo / UI-test runs so screens
/// always have a stable, "looks like a real Mac" snapshot regardless of the
/// CI machine's actual volume size.
struct DemoDiskSpaceService: DiskSpaceReading {
    let snapshot: VolumeSnapshot

    init(snapshot: VolumeSnapshot = DemoDiskSpaceService.default) {
        self.snapshot = snapshot
    }

    func currentVolume(at path: URL) async -> VolumeSnapshot { snapshot }

    /// A pretend 1 TB startup volume with ~640 GB used and ~360 GB free —
    /// large enough to feel realistic while leaving room for the demo
    /// findings to show as "potentially reclaimable" without pushing the
    /// projected-usage bar to 0%.
    static let `default` = VolumeSnapshot(
        totalBytes: 1_000_107_216_384,
        usedBytes: 640_148_254_720,
        freeBytes: 359_958_961_664
    )
}
