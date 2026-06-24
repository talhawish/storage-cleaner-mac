import SwiftUI

/// One row in the "Recent Scans" list on the Cleanup History page. Card-shaped instead of a
/// classic list row so the page reads as a stack of distinct events rather than a sparse table.
/// Shows the scan date, the top cleaned categories as chips, and the totals; tapping the card
/// opens the detail sheet via `onOpen`.
struct HistoryScanCard: View {
    let summary: CleanupScanSummary
    let onOpen: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                dateColumn
                Divider()
                    .frame(height: 78)
                    .overlay(AppTheme.hairline)
                metricsColumn
            }
            .padding(AppTheme.Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens the cleanup details for this scan")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Columns

    private var dateColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(summary.date, format: .dateTime.year())
                .font(.title2.weight(.bold).monospacedDigit())
                .lineLimit(1)
            Text(summary.date, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 110, alignment: .leading)
    }

    private var metricsColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                primaryStat
                Spacer(minLength: 0)
                scanMeta
            }
            if summary.hasDiskSnapshot {
                FreeSpacePill(summary: summary)
            }
            categoryChips
        }
    }

    private var primaryStat: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(summary.hasCleanup ? AppTheme.mint : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.hasCleanup
                     ? StorageFormatting.bytes(summary.totalBytesCleaned)
                     : "No cleanup")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(summary.hasCleanup ? .primary : .secondary)
                    .lineLimit(1)
                if summary.hasCleanup {
                    Text(
                        "\(StorageFormatting.items(summary.totalItemsCleaned)) "
                            + "item\(summary.totalItemsCleaned == 1 ? "" : "s") in "
                            + "\(summary.categories.count) "
                            + "categor\(summary.categories.count == 1 ? "y" : "ies")"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                } else {
                    Text(
                        "Scanned \(StorageFormatting.bytes(summary.reclaimableBytes)) of reclaimable space"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
    }

    private var scanMeta: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Label(
                StorageFormatting.duration(.seconds(summary.durationSeconds)),
                systemImage: "clock"
            )
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
            Label("\(summary.categoriesFound) categories", systemImage: "square.grid.2x2")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
    }

    @ViewBuilder private var categoryChips: some View {
        if summary.hasCleanup && !summary.categories.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(summary.categories.prefix(3))) { category in
                    CategoryChip(category: category)
                }
                if summary.categories.count > 3 {
                    Text("+\(summary.categories.count - 3) more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.primary.opacity(0.05))
                        )
                }
                Spacer(minLength: 0)
            }
        } else if !summary.hasCleanup {
            Label(
                "Items scanned but not removed",
                systemImage: "eye"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [
            "Scan on \(summary.date.formatted(date: .complete, time: .shortened))"
        ]
        if summary.hasCleanup {
            parts.append("Cleaned \(StorageFormatting.bytes(summary.totalBytesCleaned))")
            parts.append("\(StorageFormatting.items(summary.totalItemsCleaned)) items removed")
        } else {
            parts.append("No items removed")
        }
        if let freed = summary.freedBytesByCleanup {
            parts.append("Free space grew by \(StorageFormatting.bytes(freed))")
        }
        parts.append(
            "\(summary.categoriesFound) categories detected, "
                + "scan duration \(StorageFormatting.duration(.seconds(summary.durationSeconds)))"
        )
        return parts.joined(separator: ", ")
    }
}

/// Compact "X free before → Y free after" pill rendered inside a
/// ``HistoryScanCard``. Shown only when the persisted scan captured both
/// volume snapshots; older scans (and scan-only events without a follow-up
/// cleanup) hide the pill.
private struct FreeSpacePill: View {
    let summary: CleanupScanSummary

    private var tint: Color {
        guard let freed = summary.freedBytesByCleanup else { return .secondary }
        return freed > 0 ? AppTheme.mint : .secondary
    }

    private var freedLabel: String? {
        guard let freed = summary.freedBytesByCleanup, freed > 0 else { return nil }
        return "+\(StorageFormatting.bytes(freed))"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text("Free before")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(StorageFormatting.bytes(summary.freeBytesBefore))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Free after")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(StorageFormatting.bytes(summary.freeBytesAfter))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
            if let freedLabel {
                Text(freedLabel)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let before = StorageFormatting.bytes(summary.freeBytesBefore)
        let after = StorageFormatting.bytes(summary.freeBytesAfter)
        if let freed = summary.freedBytesByCleanup, freed > 0 {
            return "Free space \(before) before, \(after) after, grew by "
                + "\(StorageFormatting.bytes(freed))"
        }
        return "Free space \(before) before, \(after) after"
    }
}

/// Compact pill showing a single cleaned category with its icon and reclaimed bytes. Rendered
/// inside a ``HistoryScanCard`` for at-a-glance recognition of which categories were touched.
private struct CategoryChip: View {
    let category: CleanupCategorySummary

    private var tint: Color { AppTheme.color(for: category.domain) }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.domain.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(category.kind.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Text(StorageFormatting.bytes(category.bytesReclaimed))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(tint.opacity(0.10))
        )
        .overlay {
            Capsule().stroke(tint.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(category.kind.title), \(StorageFormatting.bytes(category.bytesReclaimed)) reclaimed"
        )
    }
}
