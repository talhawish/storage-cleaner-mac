import SwiftUI
import AppKit

struct MediaCategoryView: View {
    let title: String
    let findings: [StorageFinding]
    let emptyStateMessage: String
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void

    @State private var selectedURLs: Set<URL> = []
    @State private var searchText = ""
    @State private var sortOption: MediaSortOption = .sizeDesc
    @State private var viewMode: MediaViewMode = .grid
    @State private var mediaFilter: MediaFilter = .all
    @State private var showDeleteConfirmation = false
    @State private var previewURL: URL?
    @State private var visibleRecordLimit = MediaPagination.initialLimit
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var allFilePaths: [URL] {
        findings.flatMap(\.filePaths)
    }

    private var allRecords: [MediaFileRecord] {
        allFilePaths.map { url in
            MediaFileRecord(
                url: url,
                size: StorageFormatting.fileSize(at: url),
                modificationDate: StorageFormatting.modificationDate(at: url),
                isVideo: DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased())
            )
        }
    }

    private var filteredRecords: [MediaFileRecord] {
        allRecords
            .filter { record in
                let matchesSearch = searchText.isEmpty ||
                    record.url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                let matchesFilter: Bool
                switch mediaFilter {
                case .all: matchesFilter = true
                case .images: matchesFilter = !record.isVideo
                case .videos: matchesFilter = record.isVideo
                }
                return matchesSearch && matchesFilter
            }
            .sorted(by: sortOption)
    }

    private var visibleRecords: ArraySlice<MediaFileRecord> {
        filteredRecords.prefix(visibleRecordLimit)
    }

    private var hasMoreRecords: Bool {
        visibleRecordLimit < filteredRecords.count
    }

    private var totalSize: Int64 {
        findings.reduce(0) { $0 + $1.bytes }
    }

    private var selectedTotalSize: Int64 {
        let sizesByURL = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.url, $0.size) })
        return selectedURLs.reduce(Int64(0)) { $0 + (sizesByURL[$1] ?? 0) }
    }

    private var imageCount: Int {
        allRecords.filter { !$0.isVideo }.count
    }

    private var videoCount: Int {
        allRecords.filter(\.isVideo).count
    }

    var body: some View {
        Group {
            if allFilePaths.isEmpty {
                emptyState
            } else {
                mediaContent
            }
        }
        .navigationTitle(title)
        .navigationSubtitle("\(allFilePaths.count) items · \(StorageFormatting.bytes(totalSize))")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !selectedURLs.isEmpty {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }

            ToolbarItem {
                Button {
                    onScan()
                } label: {
                    Label("Scan Now", systemImage: "sparkle.magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan storage locations again")
            }

            ToolbarItem {
                Picker("View", selection: $viewMode) {
                    ForEach(MediaViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode == .grid ? "square.grid.2x2" : "list.bullet").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            ToolbarItem {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(MediaSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .accessibilityLabel("Sort")
                }
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                finding: StorageFinding(
                    kind: findings.first?.kind ?? .screenshots,
                    domain: findings.first?.domain ?? .screenshots,
                    bytes: selectedTotalSize,
                    itemCount: selectedURLs.count,
                    safety: .review,
                    examples: [],
                    filePaths: Array(selectedURLs)
                ),
                selectedURLs: Array(selectedURLs),
                totalBytes: selectedTotalSize,
                onDelete: {
                    let urls = Array(selectedURLs)
                    selectedURLs.removeAll()
                    onDelete(urls)
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { previewURL != nil },
            set: { if !$0 { previewURL = nil } }
        )) {
            if let url = previewURL {
                MediaPreviewSheet(url: url)
            }
        }
        .onChange(of: searchText) { _, _ in resetPagination() }
        .onChange(of: sortOption) { _, _ in resetPagination() }
        .onChange(of: mediaFilter) { _, _ in resetPagination() }
        .onChange(of: viewMode) { _, _ in resetPagination() }
    }

    private var emptyState: some View {
        AnimatedEmptyState(
            title: title,
            message: emptyStateMessage,
            actionTitle: "Scan Now",
            systemImage: "photo.on.rectangle.angled",
            action: onScan
        )
        .frame(minHeight: 430)
    }

    private var mediaContent: some View {
        VStack(spacing: 0) {
            MediaSummaryHeader(
                title: title,
                itemCount: allFilePaths.count,
                totalSize: totalSize,
                imageCount: imageCount,
                videoCount: videoCount
            )
            MediaFilterBar(searchText: $searchText, mediaFilter: $mediaFilter)
            MediaSelectionBar(
                selectedCount: selectedURLs.count,
                selectedTotalSize: selectedTotalSize,
                filteredCount: filteredRecords.count,
                isSelectionEmpty: selectedURLs.isEmpty,
                onToggleAll: toggleAll
            )

            if viewMode == .grid {
                gridContent
            } else {
                listContent
            }
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 116, maximum: 150), spacing: 14)
            ], spacing: 18) {
                ForEach(visibleRecords) { record in
                    MediaGridItem(
                        url: record.url,
                        isSelected: selectedURLs.contains(record.url),
                        onToggle: { toggle(record.url) },
                        onPreview: { previewURL = record.url }
                    )
                }

                if hasMoreRecords {
                    MediaPaginationFooter(
                        visibleCount: visibleRecords.count,
                        totalCount: filteredRecords.count,
                        onLoadMore: loadMoreRecords
                    )
                    .gridCellColumns(2)
                }
            }
            .padding(20)
        }
    }

    private var listContent: some View {
        List {
            ForEach(visibleRecords) { record in
                MediaListRow(
                    url: record.url,
                    isSelected: selectedURLs.contains(record.url),
                    onToggle: { toggle(record.url) },
                    onPreview: { previewURL = record.url }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
            }

            if hasMoreRecords {
                MediaPaginationFooter(
                    visibleCount: visibleRecords.count,
                    totalCount: filteredRecords.count,
                    onLoadMore: loadMoreRecords
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
        }
        .listStyle(.plain)
    }

}

private extension MediaCategoryView {
    func toggleAll() {
        if selectedURLs.isEmpty {
            selectedURLs = Set(filteredRecords.map(\.url))
        } else {
            selectedURLs.removeAll()
        }
    }

    func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    func resetPagination() {
        visibleRecordLimit = MediaPagination.initialLimit
    }

    func loadMoreRecords() {
        guard hasMoreRecords else { return }
        visibleRecordLimit = min(visibleRecordLimit + MediaPagination.pageSize, filteredRecords.count)
    }
}

private enum MediaPagination {
    static let initialLimit = 60
    static let pageSize = 60
}
