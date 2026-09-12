import SwiftUI

/// Read-only snapshot of the most recent completed overall scan. Cleanup events are deliberately
/// rendered elsewhere so this card remains focused on what the latest inventory found.
struct LatestOverallScanCard: View {
    let summary: CleanupScanSummary

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.large) {
            Image(
                systemName: summary.reclaimableBytes > 0
                    ? "externaldrive.badge.magnifyingglass"
                    : "checkmark.seal.fill"
            )
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(summary.reclaimableBytes > 0 ? AppTheme.accent : AppTheme.mint)
                .frame(width: 44, height: 44)
                .background(iconTint.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(primaryText)
                    .font(.title3.bold().monospacedDigit())
                    .lineLimit(1)
                Text(summary.date, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: AppTheme.Spacing.medium)

            HStack(spacing: AppTheme.Spacing.large) {
                metric(
                    StorageFormatting.items(summary.scannedItemCount),
                    title: "Items scanned",
                    systemImage: "doc.text.magnifyingglass"
                )
                metric(
                    "\(summary.categoriesFound)",
                    title: "Categories",
                    systemImage: "square.grid.2x2"
                )
                metric(
                    StorageFormatting.duration(.seconds(summary.durationSeconds)),
                    title: "Duration",
                    systemImage: "clock"
                )
            }
        }
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier("latest-overall-scan-card")
    }

    private var primaryText: String {
        if summary.reclaimableBytes > 0 {
            return "\(StorageFormatting.bytes(summary.reclaimableBytes)) reclaimable"
        }
        return "Nothing to clean"
    }

    private var iconTint: Color {
        summary.reclaimableBytes > 0 ? AppTheme.accent : AppTheme.mint
    }

    private func metric(_ value: String, title: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
        }
    }

    private var accessibilityDescription: String {
        "Latest overall scan, \(primaryText), "
            + "\(StorageFormatting.items(summary.scannedItemCount)) items scanned, "
            + "\(summary.categoriesFound) categories, "
            + "\(StorageFormatting.duration(.seconds(summary.durationSeconds))), "
            + summary.date.formatted(date: .complete, time: .shortened)
    }
}
