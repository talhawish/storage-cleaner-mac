import SwiftUI

/// The Quick Clean modal. Owns the phase machine and the per-category
/// expansion state; everything else lives in the subcomponents under
/// `Components/` so this file stays under the type-body-length limit.
struct QuickCleanView: View {
    let onClean: @MainActor ([URL]) async -> CleanupResult
    var onOpenSettings: (() -> Void)?
    /// Closure the modal calls whenever it needs the latest free-bytes
    /// snapshot for the volume. Defaults to a no-op so callers that don't
    /// care about disk-space telemetry (UI tests, previews) keep working
    /// unchanged.
    var freeBytesProvider: (@MainActor () async -> Int64?)?

    @Environment(\.dismiss)
    private var dismiss
    @State private var viewModel: QuickCleanViewModel
    @State private var expandedCategoryIDs: Set<String> = []
    @State private var showCleanConfirmation = false

    init(
        onClean: @escaping @MainActor ([URL]) async -> CleanupResult,
        onOpenSettings: (() -> Void)? = nil,
        freeBytesProvider: (@MainActor () async -> Int64?)? = nil
    ) {
        self.onClean = onClean
        self.onOpenSettings = onOpenSettings
        self.freeBytesProvider = freeBytesProvider
        _viewModel = State(
            initialValue: QuickCleanViewModel(
                onClean: onClean,
                volumeProvider: freeBytesProvider ?? { nil }
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            content
        }
        .frame(width: 680, height: 560)
        .background(AppTheme.appBackground)
        .sheet(isPresented: $showCleanConfirmation) {
            confirmationSheet
        }
        .onDisappear { viewModel.cancelScan() }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .idle:
            readyView
        case .scanning:
            scanningView
        case .review:
            reviewView
        case .cleaning:
            cleaningView
        case .success:
            successView
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        QuickCleanHeader(
            subtitle: headerSubtitle,
            showsSettingsButton: onOpenSettings != nil
                && (viewModel.phase == .idle || viewModel.phase == .review),
            onSettings: { onOpenSettings?() },
            onClose: { dismiss() }
        )
    }

    private var headerSubtitle: String {
        switch viewModel.phase {
        case .idle:
            return "Scan and remove safe-to-delete files in one step"
        case .scanning:
            return "Scanning enabled categories…"
        case .review:
            return "Review the items you'd like to clean"
        case .cleaning:
            return "Moving selected items to Trash…"
        case .success:
            if let result = viewModel.lastResult,
               result.deletedCount == 0,
               result.failedCount == 0 {
                return "No items were found to clean"
            }
            return "Cleanup finished"
        }
    }

    // MARK: - Phases

    private var readyView: some View {
        QuickCleanReadyView(
            onStartScan: { viewModel.startScan() }
        )
    }

    private var scanningView: some View {
        QuickCleanScanningView(
            progress: viewModel.progress
        )
    }

    private var reviewView: some View {
        VStack(spacing: 0) {
            QuickCleanSummaryBar(
                selectedItemCount: viewModel.totalSelectedItems,
                selectedBytes: viewModel.totalSelectedBytes,
                totalCategories: viewModel.populatedCategories.count,
                onSelectAll: viewModel.selectAll,
                onDeselectAll: viewModel.deselectAll
            )
            Divider()
            reviewList
            Divider()
            reviewFooter
        }
    }

    private var reviewList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.populatedCategories) { category in
                    QuickCleanCategoryCard(
                        category: category,
                        isExpanded: expandedCategoryIDs.contains(category.id) || expandedCategoryIDs.isEmpty,
                        isFullySelected: viewModel.isCategoryFullySelected(category),
                        isPartiallySelected: viewModel.isCategoryPartiallySelected(category),
                        tint: QuickCleanPalette.color(for: category),
                        onToggleCategory: { viewModel.toggleCategory(category) },
                        onToggleExpansion: { toggleExpansion(for: category.id) },
                        onToggleItem: { viewModel.toggle($0.url) },
                        isItemSelected: { viewModel.isSelected($0.url) }
                    )
                }
            }
            .padding(20)
        }
    }

    private var reviewFooter: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                showCleanConfirmation = true
            } label: {
                Label("Review & Confirm", systemImage: "checkmark.shield.fill")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.hasSelection)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var cleaningView: some View {
        QuickCleanCleaningView(itemCount: viewModel.totalSelectedItems)
    }

    private var successView: some View {
        QuickCleanSuccessView(
            result: viewModel.lastResult,
            cleanedCategories: cleanedCategories(),
            freeBytesBefore: viewModel.freeBytesAtStart,
            freeBytesAfter: viewModel.freeBytesAtEnd,
            onScanAgain: { viewModel.startScan() },
            onClose: { dismiss() }
        )
    }

    private func cleanedCategories() -> [QuickCleanCategory] {
        guard let result = viewModel.lastResult else { return [] }
        let deletedURLs = Set(result.deletedItems.map(\.originalURL))
        return viewModel.scan.populatedCategories.filter { category in
            category.items.contains { deletedURLs.contains($0.url) }
        }
    }

    // MARK: - Confirmation

    @ViewBuilder private var confirmationSheet: some View {
        let urls = viewModel.selection
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        let selectedSafety = viewModel.populatedCategories
            .filter { $0.items.contains { viewModel.isSelected($0.url) } }
            .map(\.safety)
            .contains(.review) ? CleanupSafety.review : CleanupSafety.safe
        let finding = StorageFinding(
            kind: .junkFiles,
            domain: .otherCaches,
            bytes: viewModel.totalSelectedBytes,
            itemCount: urls.count,
            safety: selectedSafety,
            examples: viewModel.populatedCategories.prefix(3).map(\.name),
            filePaths: urls
        )
        DeleteConfirmationSheet(
            finding: finding,
            selectedURLs: urls,
            totalBytes: viewModel.totalSelectedBytes,
            onDelete: {
                showCleanConfirmation = false
                viewModel.performCleanup()
            },
            onCancel: { showCleanConfirmation = false }
        )
    }

    // MARK: - Helpers

    private func toggleExpansion(for id: String) {
        if expandedCategoryIDs.isEmpty {
            // First interaction: collapse everything except the tapped one.
            expandedCategoryIDs = Set(viewModel.populatedCategories.map(\.id))
                .subtracting([id])
            return
        }
        if expandedCategoryIDs.contains(id) {
            expandedCategoryIDs.remove(id)
        } else {
            expandedCategoryIDs.insert(id)
        }
    }
}
