import SwiftUI

struct CategoryDetailView: View {
    let finding: StorageFinding
    let onDelete: ([URL]) -> Void

    @State private var selectedURLs: Set<URL> = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var showDeleteConfirmation = false
    @State private var showInfo = false
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
        let urls = finding.filePaths
        guard !searchText.isEmpty else { return sortedURLs(from: urls) }
        let filtered = urls.filter { url in
            url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
                || url.deletingLastPathComponent().path.localizedCaseInsensitiveContains(searchText)
        }
        return sortedURLs(from: filtered)
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in total + StorageFormatting.fileSize(at: url) }
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
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                finding: finding,
                selectedURLs: Array(selectedURLs),
                totalBytes: totalSelectedBytes,
                onDelete: {
                    let urls = Array(selectedURLs)
                    selectedURLs.removeAll()
                    onDelete(urls)
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
        .sheet(isPresented: $showInfo) {
            CategoryInfoSheet(finding: finding)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !selectedURLs.isEmpty {
                Button {
                    showDeleteConfirmation = true
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
            }
            .help("Sort files")
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
            }
        }
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            detailHeader

            Divider()

            searchBar

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
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
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

            Text("\(filteredURLs.count) of \(finding.filePaths.count) items")
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
            ForEach(filteredURLs, id: \.self) { url in
                FileRowView(
                    url: url,
                    isSelected: selectedURLs.contains(url),
                    onToggle: { toggle(url) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
            }
        }
        .listStyle(.plain)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: filteredURLs.count)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(finding.kind.title, systemImage: finding.domain.symbolName)
        } description: {
            Text("No individual file paths were captured for this category during the scan.")
        }
        .navigationTitle(finding.kind.title)
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
        case .sizeDesc:
            urls.sorted { StorageFormatting.fileSize(at: $0) > StorageFormatting.fileSize(at: $1) }
        case .sizeAsc:
            urls.sorted { StorageFormatting.fileSize(at: $0) < StorageFormatting.fileSize(at: $1) }
        case .nameAsc:
            urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        case .nameDesc:
            urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedDescending }
        case .dateAsc:
            urls.sorted { StorageFormatting.modificationDate(at: $0) < StorageFormatting.modificationDate(at: $1) }
        case .dateDesc:
            urls.sorted { StorageFormatting.modificationDate(at: $0) > StorageFormatting.modificationDate(at: $1) }
        }
    }
}
