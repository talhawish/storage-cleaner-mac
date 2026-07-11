import SwiftData
import SwiftUI

/// "Cleanup History" page — surfaces what the user has cleaned over time, with a hero summary,
/// a top-categories breakdown, and a card-style list of recent scans. Uses a `ScrollView` rather
/// than a `List` so the hero and breakdown grid sit on the same vertical canvas and breathe
/// against the page background.
struct CleanupHistoryView: View {
    var canRevealInFinder = true
    /// Non-nil when the history store failed to persist a record. Rendered as
    /// a dismissible warning so the user knows the audit trail is incomplete.
    var persistenceWarning: String?
    /// Deletes all stored history after the confirmation sheet. `nil` hides
    /// the toolbar action (e.g. previews without a store).
    var onClearHistory: (() -> Void)?

    @Query(
        sort: \StoredScan.date,
        order: .reverse
    )
    private var scans: [StoredScan]

    @State private var viewModel = CleanupHistoryViewModel()
    @State private var selectedSummary: CleanupScanSummary?
    @State private var isWarningDismissed = false
    @State private var showClearConfirmation = false

    private let pagePadding: CGFloat = 28
    private let contentSpacing: CGFloat = AppTheme.contentSpacing

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: contentSpacing) {
                header

                if let persistenceWarning, !isWarningDismissed {
                    persistenceWarningBanner(persistenceWarning)
                }

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
        .toolbar { clearHistoryToolbarItem }
        .sheet(item: $selectedSummary) { summary in
            CleanupDetailSheet(summary: summary, canRevealInFinder: canRevealInFinder)
        }
        .sheet(isPresented: $showClearConfirmation) {
            ConfirmationModal(
                variant: .destructive,
                title: "Clear all history?",
                message: "This permanently removes every recorded scan and cleanup from the history. "
                    + "Files already moved to Trash are not affected.",
                showsCloseButton: false,
                preferredHeight: 280,
                confirm: AppModalActionBar.Action(
                    title: "Clear History",
                    systemImage: "trash",
                    isProminent: true,
                    isDestructive: true,
                    action: {
                        onClearHistory?()
                        showClearConfirmation = false
                    }
                ),
                cancel: AppModalActionBar.CancelAction(
                    action: { showClearConfirmation = false }
                )
            )
            .accessibilityIdentifier("clear-history-confirmation")
        }
    }

    @ToolbarContentBuilder private var clearHistoryToolbarItem: some ToolbarContent {
        ToolbarItem {
            if onClearHistory != nil && !scans.isEmpty {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                }
                .help("Clear all history")
                .accessibilityLabel("Clear all history")
                .accessibilityHint("Permanently removes every recorded scan and cleanup")
                .accessibilityIdentifier("clear-history-button")
            }
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

    // MARK: - Persistence warning

    private func persistenceWarningBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.amber)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recent activity couldn't be saved to history")
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button {
                isWarningDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dismiss this warning")
            .accessibilityLabel("Dismiss history warning")
        }
        .padding(AppTheme.Spacing.medium)
        .cardSurface()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history-persistence-warning")
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
