import SwiftUI

/// Grouped duplicate management. Each duplicate group shows every byte-identical copy as a media
/// thumbnail; one copy is recommended to keep and the rest are pre-selected for removal. Users can
/// remove all duplicates at once, clear a single group, re-elect which copy to keep, or hand-pick.
struct DuplicatesView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void

    @State private var selection = DuplicateSelectionState()
    @State private var filter: DuplicateMediaFilter = .all
    @State private var previewURL: URL?
    @State private var showDeleteConfirmation = false

    /// Duplicate groups for the active filter, largest reclaim first.
    private var groups: [DuplicateGroup] {
        let kinds = Set(filter.kinds)
        let matching: [DuplicateGroup] = findings
            .filter { kinds.contains($0.kind) }
            .flatMap(\.duplicateGroups)
        return matching.sorted { lhs, rhs in
            lhs.reclaimableBytes != rhs.reclaimableBytes
                ? lhs.reclaimableBytes > rhs.reclaimableBytes
                : lhs.contentHash < rhs.contentHash
        }
    }

    private var hasAnyDuplicates: Bool {
        findings.contains { !$0.duplicateGroups.isEmpty }
    }

    private var selectedURLs: [URL] { selection.removalURLs(in: groups) }
    private var totalReclaimableBytes: Int64 { groups.reduce(0) { $0 + $1.reclaimableBytes } }
    private var totalCopyCount: Int { groups.reduce(0) { $0 + $1.files.count } }

    private var previewPresented: Binding<Bool> {
        Binding(get: { previewURL != nil }, set: { if !$0 { previewURL = nil } })
    }

    var body: some View {
        Group {
            if !hasAnyDuplicates {
                emptyState
            } else if groups.isEmpty {
                filteredEmptyState
            } else {
                content
            }
        }
        .navigationTitle("Duplicates")
        .accessibilityIdentifier("duplicates-root")
        .sheet(isPresented: previewPresented) {
            if let previewURL {
                MediaPreviewSheet(url: previewURL)
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmationModal(
                variant: .destructive,
                title: "Remove \(selectedURLs.count) duplicate copies?",
                message: deleteMessage,
                iconSystemName: "doc.on.doc.fill",
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Move to Trash",
                    systemImage: "trash.fill",
                    isProminent: true,
                    isDestructive: true,
                    isDefault: true,
                    action: performDelete
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
    }

    private var deleteMessage: String {
        let size = StorageFormatting.bytes(selection.removalBytes(in: groups))
        return "This moves \(selectedURLs.count) duplicate copies (\(size)) to the Trash. "
            + "The copy marked “Keep” in each group is left untouched."
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            DuplicatesSummaryHeader(
                groupCount: groups.count,
                copyCount: totalCopyCount,
                totalReclaimableBytes: totalReclaimableBytes,
                selectedCount: selectedURLs.count,
                selectedBytes: selection.removalBytes(in: groups),
                filter: $filter,
                onSelectAll: { for group in groups { selection.selectAllRemovable(in: group) } },
                onDeselectAll: { for group in groups { selection.clearSelection(in: group) } },
                onReset: { selection.reset() },
                onRemoveSelected: { showDeleteConfirmation = true }
            )

            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.mediumLarge) {
                    ForEach(groups) { group in
                        DuplicateGroupCard(
                            group: group,
                            selection: selection,
                            onToggleRemoval: { selection.toggleRemoval($0, in: group) },
                            onSetKeep: { selection.setKeep($0, in: group) },
                            onKeepBestRemoveOthers: { keepBestRemoveOthers(in: group) },
                            onPreview: { previewURL = $0 }
                        )
                    }
                }
                .padding(AppTheme.Spacing.mediumLarge)
            }
        }
    }

    // MARK: - Empty states

    private var emptyState: some View {
        EmptyStateView(
            title: "No duplicates to clean",
            message: "Every photo, video, and document in the scanned locations is unique. "
                + "Run another scan after adding new media to keep duplicates in check.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: onScan
        )
    }

    private var filteredEmptyState: some View {
        EmptyStateView(
            title: "No \(filter.rawValue) Duplicates",
            message: "Try a different filter to see duplicate groups.",
            systemImage: "line.3.horizontal.decrease.circle",
            tint: AppTheme.accent
        )
    }

    // MARK: - Actions

    private func keepBestRemoveOthers(in group: DuplicateGroup) {
        selection.setKeep(selection.keepURL(for: group), in: group)
        selection.selectAllRemovable(in: group)
    }

    private func performDelete() {
        let urls = selectedURLs
        guard !urls.isEmpty else { return }
        selection.reset()
        onDelete(urls)
    }
}
