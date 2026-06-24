import SwiftUI

/// Modal shown when a user taps a `HistoryScanCard` in Cleanup History. The card is already a
/// short, scannable summary; the sheet carries the same data plus a per-category breakdown and
/// representative paths so the user can confirm exactly what was cleaned.
struct CleanupDetailSheet: View {
    let summary: CleanupScanSummary

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        AppModal(
            idealWidth: 640,
            minHeight: 520,
            idealHeight: 600,
            maxHeight: 720
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: "calendar.badge.clock",
                    iconTint: AppTheme.accent,
                    title: summary.date.formatted(.dateTime.weekday(.wide).month().day().year()),
                    subtitle: summary.date.formatted(.dateTime.hour().minute()),
                    trailing: .statusBadge(text: "Scan", tint: AppTheme.accent),
                    showsCloseButton: false
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        summaryStats

                        if summary.hasCleanup {
                            cleanupBreakdown
                        } else {
                            noCleanupState
                        }
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Done",
                            systemImage: "checkmark",
                            tint: AppTheme.accent,
                            isDefault: true,
                            action: { dismiss() }
                        )
                    ],
                    style: .compact
                )
            }
        }
        .accessibilityIdentifier("cleanup-history-detail-\(summary.scanID)")
    }

    // MARK: - Sections

    private var summaryStats: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.mediumLarge) {
                AppModalStat(
                    title: "Storage Cleaned",
                    value: StorageFormatting.bytes(summary.totalBytesCleaned),
                    systemImage: "checkmark.circle.fill",
                    tint: AppTheme.mint
                )
                AppModalStat(
                    title: "Items Removed",
                    value: StorageFormatting.items(summary.totalItemsCleaned),
                    systemImage: "trash.fill",
                    tint: AppTheme.rose
                )
                AppModalStat(
                    title: "Scan Duration",
                    value: StorageFormatting.duration(.seconds(summary.durationSeconds)),
                    systemImage: "clock.fill",
                    tint: AppTheme.accent
                )
            }
            if summary.hasDiskSnapshot {
                diskSpaceRow
            }
        }
    }

    @ViewBuilder private var diskSpaceRow: some View {
        let before = StorageFormatting.bytes(summary.freeBytesBefore)
        let after = StorageFormatting.bytes(summary.freeBytesAfter)
        let freed = summary.freedBytesByCleanup
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: "internaldrive")
                .foregroundStyle(AppTheme.cyan)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Free space")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                if let freed, freed > 0 {
                    Text(
                        "\(before) → \(after) "
                            + "(+\(StorageFormatting.bytes(freed)))"
                    )
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                } else {
                    Text("\(before) → \(after)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.cyan.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            freed.map { "Free space \(before) before, \(after) after, grew by \(StorageFormatting.bytes($0))" }
                ?? "Free space \(before) before, \(after) after"
        )
    }

    private var cleanupBreakdown: some View {
        AppModalSection(
            title: "What Was Cleaned",
            subtitle: "Categories removed during this session",
            systemImage: "trash.circle.fill",
            tint: AppTheme.rose
        ) {
            VStack(spacing: AppTheme.Spacing.small) {
                ForEach(summary.categories) { category in
                    CleanupCategoryRow(summary: category, totalBytes: summary.totalBytesCleaned)
                }
            }
        }
    }

    private var noCleanupState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trash.slash.fill")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No items were removed during this scan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(
                "Scanned \(StorageFormatting.items(summary.scannedItemCount)) items across "
                    + "\(summary.categoriesFound) categories and found "
                    + "\(StorageFormatting.bytes(summary.reclaimableBytes)) of reclaimable space."
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct CleanupCategoryRow: View {
    let summary: CleanupCategorySummary
    let totalBytes: Int64

    private var tint: Color { AppTheme.color(for: summary.domain) }
    private var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(summary.bytesReclaimed) / Double(totalBytes))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                Image(systemName: summary.domain.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Text(
                        "\(StorageFormatting.items(summary.itemCount)) "
                            + "item\(summary.itemCount == 1 ? "" : "s") removed"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text(StorageFormatting.bytes(summary.bytesReclaimed))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(tint)
                .accessibilityLabel("Share of total storage cleaned")
                .accessibilityValue("\(Int(fraction * 100)) percent")

            if !summary.samplePaths.isEmpty {
                pathList
            }
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.kind.title), \(StorageFormatting.items(summary.itemCount)) items, "
                + "\(StorageFormatting.bytes(summary.bytesReclaimed)) reclaimed"
        )
    }

    private var pathList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(summary.samplePaths, id: \.self) { url in
                HStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(url.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(url.path)
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Show \(url.lastPathComponent) in Finder")
                    .accessibilityLabel("Show \(url.lastPathComponent) in Finder")
                }
            }
        }
        .padding(.top, 4)
    }
}
