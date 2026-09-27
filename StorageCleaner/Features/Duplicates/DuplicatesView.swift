import SwiftUI

/// Grouped duplicate management. Each duplicate group shows every byte-identical copy as a media
/// thumbnail; one copy is recommended to keep and the rest are pre-selected for removal. Users can
/// remove all duplicates at once, clear a single group, re-elect which copy to keep, or hand-pick.
struct DuplicatesView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) async -> CleanupResult
    let permissionHandler: (any StoragePermissionHandling)?
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var selection = DuplicateSelectionState()
    @State private var filter: DuplicateMediaFilter = .all
    @State private var previewURL: URL?
    @State private var cleanupRequest: FileCleanupRequest?
    @State private var isDeleting = false

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
            } else {
                VStack(spacing: 0) {
                    if isDeleting {
                        ProgressView("Moving duplicate files…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
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
                        onRemoveSelected: requestDeleteConfirmation
                    )
                    .disabled(isDeleting)

                    if groups.isEmpty {
                        filteredEmptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppTheme.Spacing.mediumLarge) {
                                ForEach(groups) { group in
                                    DuplicateGroupCard(
                                        group: group,
                                        selection: selection,
                                        onToggleRemoval: { selection.toggleRemoval($0, in: group) },
                                        onSetKeep: { selection.setKeep($0, in: group) },
                                        onKeepBestRemoveOthers: { keepBestRemoveOthers(in: group) },
                                        onPreview: { previewURL = $0 },
                                        permissionHandler: permissionHandler,
                                        canRevealInFinder: canUseProActions
                                    )
                                }
                            }
                            .padding(AppTheme.Spacing.mediumLarge)
                        }
                        .disabled(isDeleting)
                    }
                }
            }
        }
        .navigationTitle("Duplicates")
        .accessibilityIdentifier("duplicates-root")
        .sheet(isPresented: previewPresented) {
            if let previewURL {
                MediaPreviewSheet(
                    url: previewURL,
                    permissionHandler: permissionHandler,
                    canRevealInFinder: canUseProActions
                )
            }
        }
        .sheet(item: $cleanupRequest) { request in
            DeleteConfirmationSheet(
                selectedURLs: request.urls,
                totalBytes: request.totalBytes,
                onDelete: { performDelete(request) },
                onCancel: { cleanupRequest = nil }
            )
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

    private func performDelete(_ request: FileCleanupRequest) {
        guard !isDeleting else { return }
        cleanupRequest = nil
        isDeleting = true
        Task { @MainActor in
            _ = await onDelete(request.urls)
            isDeleting = false
        }
    }

    private func requestDeleteConfirmation() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        cleanupRequest = FileCleanupRequest(
            urls: selectedURLs,
            totalBytes: selection.removalBytes(in: groups)
        )
    }
}
