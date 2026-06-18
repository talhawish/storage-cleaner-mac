import SwiftUI
import AppKit

struct MediaCategoryView: View {
    let title: String
    let findings: [StorageFinding]
    let onDelete: ([URL]) -> Void

    @State private var selectedURLs: Set<URL> = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var viewMode: ViewMode = .grid
    @State private var showDeleteConfirmation = false
    @State private var previewURL: URL?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Largest First"
        case sizeAsc = "Smallest First"
        case nameAsc = "Name A–Z"
        case nameDesc = "Name Z–A"
        case dateDesc = "Newest First"
        case dateAsc = "Oldest First"
    }

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
    }

    private var allFilePaths: [URL] {
        findings.flatMap(\.filePaths)
    }

    private var filteredURLs: [URL] {
        let urls = allFilePaths
        guard !searchText.isEmpty else { return sortedURLs(from: urls) }
        let filtered = urls.filter { url in
            url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
        return sortedURLs(from: filtered)
    }

    private var totalSize: Int64 {
        findings.reduce(0) { $0 + $1.bytes }
    }

    private var selectedTotalSize: Int64 {
        selectedURLs.reduce(Int64(0)) { $0 + StorageFormatting.fileSize(at: $1) }
    }

    private var imageURLs: [URL] {
        filteredURLs.filter { DependencyPaths.Media.imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    private var videoURLs: [URL] {
        filteredURLs.filter { DependencyPaths.Media.videoExtensions.contains($0.pathExtension.lowercased()) }
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
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode == .grid ? "square.grid.2x2" : "list.bullet").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            ToolbarItem {
                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
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
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(title, systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("No items found for this category. Run a scan first.")
        }
    }

    private var mediaContent: some View {
        VStack(spacing: 0) {
            searchBar
            selectionBar

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
                GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredURLs, id: \.self) { url in
                    MediaGridItem(
                        url: url,
                        isSelected: selectedURLs.contains(url),
                        onToggle: { toggle(url) },
                        onPreview: { previewURL = url }
                    )
                }
            }
            .padding(20)
        }
    }

    private var listContent: some View {
        List {
            ForEach(findings) { finding in
                Section {
                    ForEach(finding.filePaths, id: \.self) { url in
                        MediaListRow(
                            url: url,
                            isSelected: selectedURLs.contains(url),
                            onToggle: { toggle(url) },
                            onPreview: { previewURL = url }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                    }
                } header: {
                    HStack {
                        Image(systemName: finding.kind == .screenshots ? "camera.viewfinder" : "film.fill")
                            .foregroundStyle(AppTheme.color(for: finding.domain))
                        Text(finding.kind.title)
                        Spacer()
                        Text(StorageFormatting.bytes(finding.bytes))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
        }
        .listStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Search files…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button {
                if !selectedURLs.isEmpty {
                    selectedURLs.removeAll()
                } else {
                    selectedURLs = Set(allFilePaths)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedURLs.isEmpty ? "checkmark.circle" : "xmark.circle")
                    Text(selectedURLs.isEmpty ? "Select All" : "Deselect All")
                        .font(.subheadline.weight(.medium))
                }
            }
            .buttonStyle(.plain)

            if !selectedURLs.isEmpty {
                Divider().frame(height: 16)
                Text("\(selectedURLs.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                Text(StorageFormatting.bytes(selectedTotalSize))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(filteredURLs.count) items")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    private func sortedURLs(from urls: [URL]) -> [URL] {
        switch sortOption {
        case .sizeDesc: urls.sorted { StorageFormatting.fileSize(at: $0) > StorageFormatting.fileSize(at: $1) }
        case .sizeAsc: urls.sorted { StorageFormatting.fileSize(at: $0) < StorageFormatting.fileSize(at: $1) }
        case .nameAsc: urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        case .nameDesc: urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedDescending }
        case .dateDesc: urls.sorted { StorageFormatting.modificationDate(at: $0) > StorageFormatting.modificationDate(at: $1) }
        case .dateAsc: urls.sorted { StorageFormatting.modificationDate(at: $0) < StorageFormatting.modificationDate(at: $1) }
        }
    }
}
