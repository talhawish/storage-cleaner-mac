import Foundation

/// A point-in-time snapshot of the user's startup volume: the total, used, and
/// free capacity available to applications, plus the projected free capacity if
/// a candidate set of bytes were reclaimed. `Equatable` so view models and
/// SwiftUI bindings can detect changes without comparing every field.
///
/// Values come from `URLResourceKey.volume*` keys (the cached attributes
/// `FileManager` already maintains), so reading them is cheap and safe to call
/// on a background actor.
struct VolumeSnapshot: Equatable, Sendable, Hashable {
    /// Total capacity of the volume, in bytes.
    let totalBytes: Int64
    /// Bytes already consumed on the volume.
    let usedBytes: Int64
    /// Bytes still available for applications.
    let freeBytes: Int64

    init(totalBytes: Int64, usedBytes: Int64, freeBytes: Int64) {
        self.totalBytes = max(0, totalBytes)
        self.usedBytes = max(0, usedBytes)
        self.freeBytes = max(0, freeBytes)
    }

    /// `0...1` fraction of the volume that is currently in use. Returns `0`
    /// when the volume has no reported capacity (rare — typically means the
    /// caller's container isn't backed by a real disk).
    var usageFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(totalBytes)))
    }

    /// Free bytes that *would* be available after reclaiming `reclaimableBytes`
    /// from the volume, clamped so it never exceeds the total capacity. Used
    /// to project the "after cleanup" state on the home screen and the Quick
    /// Clean success view.
    func projectedFreeBytes(reclaiming reclaimableBytes: Int64) -> Int64 {
        guard reclaimableBytes > 0 else { return freeBytes }
        return min(totalBytes, freeBytes + reclaimableBytes)
    }

    /// Projected usage fraction after `reclaimableBytes` are reclaimed. Mirrors
    /// `usageFraction` semantics.
    func projectedUsageFraction(reclaiming reclaimableBytes: Int64) -> Double {
        guard totalBytes > 0 else { return 0 }
        let reclaimed = max(0, min(reclaimableBytes, usedBytes))
        let projectedUsed = max(0, usedBytes - reclaimed)
        return min(1, Double(projectedUsed) / Double(totalBytes))
    }

    /// A zero snapshot used as a placeholder when the volume attributes cannot
    /// be read (e.g. inside a sandbox without the right entitlement, or a
    /// pre-volume test fixture). All three values are 0.
    static let unavailable = VolumeSnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0)

    /// `true` when the snapshot has no useful capacity information — the view
    /// layer uses this to fall back to a "capacity unavailable" message rather
    /// than rendering a misleading 0% / 0 bytes chart.
    var isAvailable: Bool { totalBytes > 0 }
}
