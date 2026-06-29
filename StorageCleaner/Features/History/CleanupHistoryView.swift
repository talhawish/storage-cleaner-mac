import SwiftData
import SwiftUI

/// "Cleanup History" page — surfaces what the user has cleaned over time, with a hero summary,
/// a top-categories breakdown, and a card-style list of recent scans. Uses a `ScrollView` rather
/// than a `List` so the hero and breakdown grid sit on the same vertical canvas and breathe
/// against the page background.
struct CleanupHistoryView: View {
    var canRevealInFinder = true

    @Query(
        sort: \StoredScan.date,
        order: .reverse
    )
    private var scans: [StoredScan]

    @State private var viewModel = CleanupHistoryViewModel()
    @State private var selectedSummary: CleanupScanSummary?

    private let pagePadding: CGFloat = 28
    private let contentSpacing: CGFloat = AppTheme.contentSpacing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: contentSpacing) {
                header

                if scans.isEmpty {
                    emptyState
                } else {
                    CleanupHeroSummary(viewModel: viewModel)

                    if !viewModel.topCategories.isEmpty {
                        TopCleanedCategoriesCard(categories: viewModel.topCategories)
                    }

                    scansSection
                }
            }
            .padding(pagePadding)
        }
        .navigationTitle("Cleanup History")
        .navigationSubtitle(navigationSubtitle)
        .accessibilityIdentifier("cleanup-history-root")
        .onAppear { viewModel.update(with: scans) }
        .onChange(of: scans.count) { _, _ in viewModel.update(with: scans) }
        .sheet(item: $selectedSummary) { summary in
            CleanupDetailSheet(summary: summary, canRevealInFinder: canRevealInFinder)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Cleanup History")
                .font(.largeTitle.bold())
            Text("See what you've cleaned over time, the categories driving the biggest impact, and "
                 + "the details of every scan.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Subtitle

    private var navigationSubtitle: String {
        guard !scans.isEmpty else { return "No scans yet" }
        if viewModel.totalScansWithCleanup == 0 {
            return "\(viewModel.totalScans) scan\(viewModel.totalScans == 1 ? "" : "s")"
        }
        return "\(viewModel.totalScansWithCleanup) cleanup\(viewModel.totalScansWithCleanup == 1 ? "" : "s")"
    }

    // MARK: - Scans section

    private var scansSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            SectionHeader(
                title: "Recent Scans",
                subtitle: scanListSubtitle,
                systemImage: "clock.arrow.circlepath"
            ) {
                Text("\(viewModel.summaries.count) total")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: AppTheme.Spacing.medium) {
                ForEach(viewModel.summaries) { summary in
                    HistoryScanCard(
                        summary: summary,
                        onOpen: { selectedSummary = summary }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cleanup-history-scans")
    }

    private var scanListSubtitle: String {
        if viewModel.summaries.count <= 1 { return "Every scan you've ever run" }
        return "Newest first"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            title: "No history yet",
            message: "Run a scan from the Overview and clean the items you don't need. The lifetime "
                + "summary, top categories, and per-scan details will appear here.",
            systemImage: "clock.arrow.circlepath",
            tint: AppTheme.mint
        )
    }
}
