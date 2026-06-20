import SwiftData
import SwiftUI

struct CleanupHistoryView: View {
    @Query(
        sort: \StoredScan.date,
        order: .reverse
    )
    private var scans: [StoredScan]

    @State private var viewModel = CleanupHistoryViewModel()
    @State private var selectedSummary: CleanupScanSummary?

    var body: some View {
        Group {
            if scans.isEmpty {
                AnimatedEmptyState(
                    title: "No History",
                    message: "Scan results and cleanup actions will appear here.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                historyList
            }
        }
        .navigationTitle("Cleanup History")
        .accessibilityIdentifier("cleanup-history-root")
        .onAppear { viewModel.update(with: scans) }
        .onChange(of: scans.count) { _, _ in viewModel.update(with: scans) }
        .sheet(item: $selectedSummary) { summary in
            CleanupDetailSheet(summary: summary)
        }
    }

    private var historyList: some View {
        List {
            Section("Overview") {
                CleanupHistorySummaryCard(viewModel: viewModel)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Recent Scans") {
                ForEach(viewModel.summaries) { summary in
                    HistoryRowView(
                        summary: summary,
                        onOpen: { selectedSummary = summary }
                    )
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct HistoryRowView: View {
    let summary: CleanupScanSummary
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                    Text(summary.date, style: .date)
                        .font(.headline)
                    + Text(" at ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    + Text(summary.date, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                HStack(spacing: 16) {
                    Label(StorageFormatting.bytes(summary.reclaimableBytes), systemImage: "externaldrive.badge.xmark")
                    Label("\(summary.categoriesFound) categories", systemImage: "square.grid.2x2")
                    Label(
                        StorageFormatting.duration(.seconds(summary.durationSeconds)),
                        systemImage: "clock"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if summary.hasCleanup {
                    Divider()
                    cleanedCallout
                    if !summary.categories.isEmpty {
                        categoryPreview
                    }
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens the cleanup details for this scan")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        var parts = [
            "Scan on \(summary.date.formatted(date: .abbreviated, time: .shortened))",
            "Reclaimable: \(StorageFormatting.bytes(summary.reclaimableBytes))",
            "\(summary.categoriesFound) categories"
        ]
        if summary.hasCleanup {
            parts.append("Storage cleaned: \(StorageFormatting.bytes(summary.totalBytesCleaned))")
            parts.append("\(summary.totalItemsCleaned) items removed")
        }
        return parts.joined(separator: ", ")
    }

    private var cleanedCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.circle.fill")
                .foregroundStyle(AppTheme.rose)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Storage Cleaned")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(StorageFormatting.bytes(summary.totalBytesCleaned))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.rose)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(summary.categories.count) categor\(summary.categories.count == 1 ? "y" : "ies")")
                    .font(.caption.weight(.medium))
                Text("\(StorageFormatting.items(summary.totalItemsCleaned)) items")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.rose.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var categoryPreview: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(summary.categories.prefix(3))) { category in
                categoryLine(for: category)
            }
            if summary.categories.count > 3 {
                Text("+ \(summary.categories.count - 3) more")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            }
        }
    }

    private func categoryLine(for category: CleanupCategorySummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.domain.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.color(for: category.domain))
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(category.kind.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Spacer()

            Text("\(StorageFormatting.items(category.itemCount)) items")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(StorageFormatting.bytes(category.bytesReclaimed))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.color(for: category.domain))
                .frame(minWidth: 60, alignment: .trailing)
        }
    }
}

struct CleanupHistorySummaryCard: View {
    let viewModel: CleanupHistoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label("Lifetime Summary", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if let lastCleanup = viewModel.lastCleanupDate {
                    Text("Last cleanup: \(lastCleanup, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: AppTheme.Spacing.mediumLarge) {
                metric(
                    title: "Total Cleaned",
                    value: StorageFormatting.bytes(viewModel.totalBytesReclaimed),
                    systemImage: "checkmark.seal.fill",
                    tint: AppTheme.mint
                )
                metric(
                    title: "Items Removed",
                    value: StorageFormatting.items(viewModel.totalItemsReclaimed),
                    systemImage: "trash.fill",
                    tint: AppTheme.rose
                )
                metric(
                    title: "Scans",
                    value: "\(viewModel.totalScans)",
                    systemImage: "list.bullet.clipboard.fill",
                    tint: AppTheme.accent
                )
            }
        }
        .padding(20)
        .cardSurface()
        .accessibilityIdentifier("cleanup-history-summary")
    }

    private func metric(title: String, value: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
