import SwiftUI

/// The hero summary at the top of Cleanup History. A flat ``cardSurface`` card that surfaces the
/// lifetime cleaned total as a big number, a "last cleanup" chip, and a row of three stat tiles.
/// Mirrors the visual weight of ``OverviewSummaryBar`` so this page sits in the same family as
/// the rest of the app.
struct CleanupHeroSummary: View {
    let viewModel: CleanupHistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                headline
                Spacer(minLength: AppTheme.Spacing.medium)
                if let lastCleanup = viewModel.lastCleanupDate {
                    lastCleanupChip(for: lastCleanup)
                }
            }

            statsRow
        }
        .padding(AppTheme.Spacing.extraLarge)
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cleanup-history-hero")
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Lifetime Cleanup Impact", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mint)
                .labelStyle(.titleAndIcon)

            Text(StorageFormatting.bytes(viewModel.totalBytesReclaimed))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Lifetime cleaned: \(StorageFormatting.bytes(viewModel.totalBytesReclaimed))")

            Text(headlineSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headlineSubtitle: String {
        if viewModel.totalBytesReclaimed == 0 {
            return "Run a scan and clean what you don't need — your impact will show up here."
        }
        if let firstDate = viewModel.firstCleanupDate {
            let relative = firstDate.formatted(.relative(presentation: .named))
            return "Across \(viewModel.totalScansWithCleanup) cleanups since \(relative)."
        }
        return "Across \(viewModel.totalScansWithCleanup) cleanups so far."
    }

    private func lastCleanupChip(for date: Date) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Last Cleanup")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mint)
                Text(date, format: .relative(presentation: .named))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppTheme.mint.opacity(0.12)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last cleanup \(date.formatted(date: .abbreviated, time: .shortened))")
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: AppTheme.Spacing.mediumLarge) {
            HistoryStatTile(
                title: "This Month",
                value: StorageFormatting.bytes(viewModel.bytesReclaimedThisMonth),
                caption: thisMonthCaption,
                systemImage: "calendar",
                tint: AppTheme.accent
            )
            HistoryStatTile(
                title: "Items Removed",
                value: StorageFormatting.items(viewModel.totalItemsReclaimed),
                caption: "lifetime",
                systemImage: "trash.fill",
                tint: AppTheme.rose
            )
            HistoryStatTile(
                title: "Biggest Cleanup",
                value: biggestCleanupValue,
                caption: biggestCleanupCaption,
                systemImage: "trophy.fill",
                tint: AppTheme.amber
            )
        }
    }

    private var thisMonthCaption: String {
        if viewModel.itemsReclaimedThisMonth == 0 {
            return "no cleanups yet"
        }
        return "\(StorageFormatting.items(viewModel.itemsReclaimedThisMonth)) items"
    }

    private var biggestCleanupValue: String {
        guard let largest = viewModel.largestCleanup else { return "—" }
        return StorageFormatting.bytes(largest.bytes)
    }

    private var biggestCleanupCaption: String {
        guard let largest = viewModel.largestCleanup else { return "no cleanups yet" }
        return largest.date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
