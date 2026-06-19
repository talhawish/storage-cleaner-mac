import SwiftUI

/// An actionable hint shown on the Overview, built by `OverviewTipBuilder` from a completed scan.
/// Views render it without any logic of their own.
struct OverviewTip: Identifiable, Equatable {
    enum Action: Equatable {
        case quickClean
        case reveal(StorageFindingKind)
    }

    let id: String
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let action: Action?
}

/// A developer-storage finding flagged stale by the view model's best-effort modification-date
/// sampling. Sendable so it can cross the off-main-thread sampling boundary.
struct StaleHint: Equatable, Sendable {
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64
    /// Days since the newest sampled file in this finding was modified.
    let daysSinceModified: Int
}

/// Builds the small set of Overview tips. Returns an empty array when nothing qualifies so the
/// carousel can hide entirely rather than show empty filler.
enum OverviewTipBuilder {
    /// Minimum age (days) before a developer cache is surfaced as "untouched".
    static let staleThresholdDays = 90

    /// At most three tips: the biggest safe-to-clean win, the safe-vs-review split, and a stale-cache
    /// nudge (only when stale sampling found something).
    static func tips(for snapshot: ScanSnapshot, stale: [StaleHint] = []) -> [OverviewTip] {
        [
            biggestQuickWin(in: snapshot.findings),
            safeReviewSplit(in: snapshot.findings),
            staleTip(from: stale)
        ].compactMap { $0 }
    }

    private static func biggestQuickWin(in findings: [StorageFinding]) -> OverviewTip? {
        guard let top = findings
            .filter({ $0.safety == .safe && $0.bytes > 0 })
            .max(by: { $0.bytes < $1.bytes })
        else { return nil }

        return OverviewTip(
            id: "quick-win",
            icon: "bolt.fill",
            tint: AppTheme.mint,
            title: "Biggest quick win",
            message: "Reclaim \(StorageFormatting.bytes(top.bytes)) from \(top.kind.title).",
            action: .reveal(top.kind)
        )
    }

    private static func safeReviewSplit(in findings: [StorageFinding]) -> OverviewTip? {
        let safe = StorageOverview.safeBytes(in: findings)
        let review = StorageOverview.reviewBytes(in: findings)
        guard safe > 0 || review > 0 else { return nil }

        return OverviewTip(
            id: "safe-review",
            icon: "checkmark.shield.fill",
            tint: AppTheme.accent,
            title: "Safe to clean now",
            message: "\(StorageFormatting.bytes(safe)) is safe to clean · "
                + "\(StorageFormatting.bytes(review)) needs review.",
            action: safe > 0 ? .quickClean : nil
        )
    }

    private static func staleTip(from stale: [StaleHint]) -> OverviewTip? {
        guard let top = stale.filter({ $0.bytes > 0 }).max(by: { $0.bytes < $1.bytes }) else {
            return nil
        }

        return OverviewTip(
            id: "stale",
            icon: "clock.badge.exclamationmark",
            tint: AppTheme.orange,
            title: "Untouched for a while",
            message: "\(top.kind.title) hasn't changed in \(top.daysSinceModified)+ days "
                + "(\(StorageFormatting.bytes(top.bytes))).",
            action: .reveal(top.kind)
        )
    }
}
