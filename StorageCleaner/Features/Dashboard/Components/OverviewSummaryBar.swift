import SwiftUI

/// Slim results header: total reclaimable space with a safe/review split and the primary actions.
/// Replaces the bulkier per-result banner so the Overview leads with the breakdown grid.
struct OverviewSummaryBar: View {
    let snapshot: ScanSnapshot
    let safeBytes: Int64
    let reviewBytes: Int64
    let startScan: () -> Void
    let quickClean: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                Text("Potentially reclaimable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(StorageFormatting.bytes(snapshot.reclaimableBytes))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                HStack(spacing: AppTheme.Spacing.small) {
                    SafetyChip(label: "\(StorageFormatting.bytes(safeBytes)) safe", safety: .safe)
                    SafetyChip(label: "\(StorageFormatting.bytes(reviewBytes)) review", safety: .review)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: AppTheme.Spacing.medium)

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.small) {
                Button(action: quickClean) {
                    Label("Quick Clean", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)

                Button("Scan Again", action: startScan)
                    .buttonStyle(.bordered)

                Text(
                    "\(StorageFormatting.items(snapshot.scannedItemCount)) items · "
                        + StorageFormatting.duration(snapshot.duration)
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.Spacing.large)
        .cardSurface()
        .accessibilityIdentifier("scan-summary")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(StorageFormatting.bytes(snapshot.reclaimableBytes)) potentially reclaimable, "
                + "\(StorageFormatting.bytes(safeBytes)) safe to clean, "
                + "\(StorageFormatting.bytes(reviewBytes)) needs review"
        )
    }
}

/// Capsule chip mirroring `StatusBadge` styling, used for the safe/review byte split.
private struct SafetyChip: View {
    let label: String
    let safety: CleanupSafety

    private var tint: Color { safety == .safe ? AppTheme.mint : AppTheme.orange }

    var body: some View {
        Label(label, systemImage: safety == .safe ? "checkmark.shield.fill" : "eye.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
