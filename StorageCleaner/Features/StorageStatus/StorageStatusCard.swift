import SwiftUI

/// Slim disk-space card that lives at the top of the Overview and the Quick
/// Clean success view. Renders a single tight row (icon · used / total · % ·
/// free · optional "after cleanup") with a thin usage bar underneath. When
/// the volume attributes are unavailable it collapses to a quiet "status
/// unavailable" line instead of inventing a number.
///
/// Kept under `Features/StorageStatus/` (not under `Dashboard/Components/` or
/// `QuickClean/Components/`) because both surfaces use it verbatim — sharing
/// the same definition keeps the UI copy and bar geometry in lockstep.
struct StorageStatusCard: View {
    let volume: VolumeSnapshot
    let totalReclaimableBytes: Int64
    let title: String
    let subtitle: String?
    let systemImage: String
    let tint: Color

    init(
        volume: VolumeSnapshot,
        totalReclaimableBytes: Int64 = 0,
        title: String = "Storage",
        subtitle: String? = nil,
        systemImage: String = "internaldrive",
        tint: Color = AppTheme.accent
    ) {
        self.volume = volume
        self.totalReclaimableBytes = totalReclaimableBytes
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
    }

    private var projectedFree: Int64 {
        volume.projectedFreeBytes(reclaiming: totalReclaimableBytes)
    }

    private var projectedUsageFraction: Double {
        volume.projectedUsageFraction(reclaiming: totalReclaimableBytes)
    }

    private var useAfter: Bool { totalReclaimableBytes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            if volume.isAvailable {
                summaryRow
                StackedUsageBar(
                    usedFraction: volume.usageFraction,
                    projectedUsedFraction: useAfter ? projectedUsageFraction : nil,
                    tint: tint
                )
            } else {
                unavailableState
            }
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.mediumLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storage-status-card")
    }

    // MARK: - Summary row

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            iconChip
            primaryReadout
            Spacer(minLength: AppTheme.Spacing.small)
            freeReadout
            if useAfter {
                afterReadout
            }
        }
    }

    private var iconChip: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.14))
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private var primaryReadout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(StorageFormatting.bytes(volume.usedBytes))
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("/")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text(StorageFormatting.bytes(volume.totalBytes))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("·")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text("\(Int((volume.usageFraction * 100).rounded()))%")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(StorageFormatting.bytes(volume.usedBytes)) used of "
                + "\(StorageFormatting.bytes(volume.totalBytes)) total, "
                + "\(Int((volume.usageFraction * 100).rounded())) percent"
        )
    }

    private var freeReadout: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("Free")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(StorageFormatting.bytes(volume.freeBytes))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Free \(StorageFormatting.bytes(volume.freeBytes))")
    }

    private var afterReadout: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            VStack(alignment: .trailing, spacing: 1) {
                Text("After cleanup")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(StorageFormatting.bytes(projectedFree))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.mint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "After cleanup \(StorageFormatting.bytes(projectedFree)), "
                + "reclaims \(StorageFormatting.bytes(totalReclaimableBytes))"
        )
    }

    private var unavailableState: some View {
        HStack(spacing: 8) {
            iconChip
            Text("Storage status unavailable — your volume attributes couldn't be read.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Two-segment stacked bar showing the volume's used space, with a subtle
/// projected overlay for the "after cleanup" state. Lives next to
/// `StorageStatusCard` because it has no meaning outside that view.
private struct StackedUsageBar: View {
    let usedFraction: Double
    let projectedUsedFraction: Double?
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.07))
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, geo.size.width * clamped(usedFraction)))
                if let projected = projectedUsedFraction, projected < usedFraction {
                    Capsule()
                        .fill(tint.opacity(0.35))
                        .frame(width: max(2, geo.size.width * clamped(projected)))
                }
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
