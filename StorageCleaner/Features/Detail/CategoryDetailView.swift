import SwiftUI

struct CategoryDetailView: View {
    let finding: StorageFinding
    let onDelete: ([URL]) -> Void
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var selectedURLs: Set<URL> = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var showDeleteConfirmation = false
    @State private var showInfo = false
    @State private var fileMetadata: [URL: DetailFileMetadata] = [:]
    @State private var childLevels: [URL: DetailDirectoryLevel] = [:]
    @State private var directoryStack: [DetailDirectoryLevel] = []
    @State private var removedURLs: Set<URL> = []
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Largest First"
        case sizeAsc = "Smallest First"
        case nameAsc = "Name A–Z"
        case nameDesc = "Name Z–A"
        case dateAsc = "Oldest First"
        case dateDesc = "Newest First"

        var systemImage: String {
            switch self {
            case .sizeDesc: "arrow.down"
            case .sizeAsc: "arrow.up"
            case .nameAsc: "textformat"
            case .nameDesc: "textformat.alt"
            case .dateAsc: "calendar"
            case .dateDesc: "calendar.badge.clock"
            }
        }
    }

    private var filteredURLs: [URL] {
        let urls = currentURLs
        guard !searchText.isEmpty else { return sortedURLs(from: urls) }
        let filtered = urls.filter { url in
            displayName(for: url).localizedCaseInsensitiveContains(searchText)
                || url.deletingLastPathComponent().path.localizedCaseInsensitiveContains(searchText)
        }
        return sortedURLs(from: filtered)
    }

    private var currentURLs: [URL] {
        let urls = directoryStack.last?.urls ?? finding.filePaths
        return urls.filter { !removedURLs.contains($0) }
    }

    private var currentLevelTitle: String {
        directoryStack.last?.title ?? finding.kind.title
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in total + (fileMetadata[url]?.bytes ?? 0) }
    }

    private var allVisibleSelected: Bool {
        !filteredURLs.isEmpty && filteredURLs.allSatisfy { selectedURLs.contains($0) }
    }

    private var someSelected: Bool {
        !selectedURLs.isEmpty && !allVisibleSelected
    }

    var body: some View {
        Group {
            if finding.filePaths.isEmpty {
                emptyState
            } else {
                detailContent
            }
        }
        .navigationTitle(finding.kind.title)
        .navigationSubtitle(finding.kind.summary)
        .accessibilityIdentifier("category-detail-\(finding.kind.rawValue)")
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                selectedURLs: Array(selectedURLs),
                totalBytes: totalSelectedBytes,
                onDelete: {
                    let urls = Array(selectedURLs)
                    removedURLs.formUnion(urls)
                    selectedURLs.removeAll()
                    showDeleteConfirmation = false
                    onDelete(urls)
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
        .sheet(isPresented: $showInfo) {
            CategoryInfoSheet(finding: finding)
        }
        .task(id: currentURLs) {
            await loadFileMetadata()
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !selectedURLs.isEmpty {
                Button {
                    requestDeleteConfirmation()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .help("Delete \(selectedURLs.count) selected items")
            }
        }

        ToolbarItem {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .accessibilityHidden(true)
            }
            .help("Sort files")
            .accessibilityLabel("Sort files")
        }

        ToolbarItem {
            Menu {
                Button {
                    selectedURLs = Set(filteredURLs)
                } label: {
                    Label("Select Visible", systemImage: "checkmark.circle")
                }
                .disabled(allVisibleSelected)

                Button {
                    selectedURLs.removeAll()
                } label: {
                    Label("Deselect All", systemImage: "circle.dashed")
                }
                .disabled(selectedURLs.isEmpty)

                Divider()

                Button {
                    showInfo = true
                } label: {
                    Label("About This Category", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("More actions")
        }
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            detailHeader

            Divider()

            SearchField(text: $searchText, prompt: "Search files…")
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            selectionBar

            fileList
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.color(for: finding.domain).opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: finding.domain.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.color(for: finding.domain))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(finding.kind.title)
                        .font(.title2.weight(.semibold))
                    StatusBadge(safety: finding.safety)
                }
                Text(finding.kind.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormatting.bytes(finding.bytes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(StorageFormatting.items(finding.itemCount)) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            if !directoryStack.isEmpty {
                Button {
                    popDirectoryLevel()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .help("Back to parent folder")

                Divider().frame(height: 16)

                Text(currentLevelTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button {
                if allVisibleSelected {
                    for url in filteredURLs { selectedURLs.remove(url) }
                } else {
                    for url in filteredURLs { selectedURLs.insert(url) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allVisibleSelected ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(allVisibleSelected ? AppTheme.accent : .secondary)
                        .accessibilityHidden(true)
                    Text(allVisibleSelected ? "Deselect Visible" : "Select Visible")
                        .font(.subheadline.weight(.medium))
                }
            }
            .buttonStyle(.plain)

            if !selectedURLs.isEmpty {
                Divider().frame(height: 16)

                Text("\(selectedURLs.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())

                Text(StorageFormatting.bytes(totalSelectedBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Text("\(filteredURLs.count) of \(currentURLs.count) items")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedURLs.count)
    }

    private var fileList: some View {
        List {
            ForEach(URLRowIdentity.rows(for: filteredURLs)) { row in
                let url = row.url
                FileRowView(
                    url: url,
                    isSelected: selectedURLs.contains(url),
                    pathDisplayMode: .fullPath,
                    metadata: fileMetadata[url],
                    canOpen: childLevels[url] != nil,
                    canRevealInFinder: canUseProActions,
                    onToggle: { toggle(url) },
                    onOpen: { pushDirectoryLevel(from: url) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
            }
        }
        .listStyle(.plain)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: filteredURLs.count)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No files in this category",
            message: "No individual file paths were captured for this category during the scan.",
            systemImage: finding.domain.symbolName,
            tint: AppTheme.color(for: finding.domain)
        )
        .navigationTitle(finding.kind.title)
    }

    private func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    private func requestDeleteConfirmation() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        showDeleteConfirmation = true
    }

    private func pushDirectoryLevel(from url: URL) {
        guard let level = childLevels[url] ?? DetailDirectoryChildren.level(for: url) else { return }
        directoryStack.append(level)
        selectedURLs.removeAll()
        searchText = ""
    }

    private func popDirectoryLevel() {
        guard !directoryStack.isEmpty else { return }
        directoryStack.removeLast()
        selectedURLs.removeAll()
        searchText = ""
    }

    private func sortedURLs(from urls: [URL]) -> [URL] {
        switch sortOption {
        case .sizeDesc:
            urls.sorted { metadataBytes(for: $0) > metadataBytes(for: $1) }
        case .sizeAsc:
            urls.sorted { metadataBytes(for: $0) < metadataBytes(for: $1) }
        case .nameAsc:
            urls.sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
            }
        case .nameDesc:
            urls.sorted {
                displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedDescending
            }
        case .dateAsc:
            urls.sorted { StorageFormatting.modificationDate(at: $0) < StorageFormatting.modificationDate(at: $1) }
        case .dateDesc:
            urls.sorted { StorageFormatting.modificationDate(at: $0) > StorageFormatting.modificationDate(at: $1) }
        }
    }

    private func metadataBytes(for url: URL) -> Int64 {
        fileMetadata[url]?.bytes ?? 0
    }

    private func displayName(for url: URL) -> String {
        fileMetadata[url]?.displayName ?? url.lastPathComponent
    }

    private func loadFileMetadata() async {
        let urls = currentURLs
        let pathBytes = finding.pathBytes
        let loaded = await Task.detached(priority: .utility) {
            let metadata = Dictionary(
                urls.map { ($0, DetailFileMetadata.load(for: $0, precomputedBytes: pathBytes[$0])) },
                uniquingKeysWith: { first, _ in first }
            )
            let levels = Dictionary(
                urls.compactMap { url in
                    DetailDirectoryChildren.level(for: url).map { (url, $0) }
                },
                uniquingKeysWith: { first, _ in first }
            )
            return (metadata, levels)
        }.value
        guard !Task.isCancelled else { return }
        fileMetadata.merge(loaded.0, uniquingKeysWith: { _, new in new })
        childLevels.merge(loaded.1, uniquingKeysWith: { _, new in new })
    }
}
