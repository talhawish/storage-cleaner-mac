import SwiftUI

enum MediaSortOption: String, CaseIterable {
    case sizeDesc = "Largest First"
    case sizeAsc = "Smallest First"
    case nameAsc = "Name A-Z"
    case nameDesc = "Name Z-A"
    case dateDesc = "Newest First"
    case dateAsc = "Oldest First"
}

enum MediaViewMode: String, CaseIterable {
    case grid = "Grid"
    case list = "List"
}

enum MediaFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"
}

struct MediaFileRecord: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let modificationDate: Date
    let isVideo: Bool

    var id: URL { url }
}

extension Array where Element == MediaFileRecord {
    func sorted(by sortOption: MediaSortOption) -> [MediaFileRecord] {
        switch sortOption {
        case .sizeDesc:
            sorted { $0.size > $1.size }
        case .sizeAsc:
            sorted { $0.size < $1.size }
        case .nameAsc:
            sorted {
                $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending
            }
        case .nameDesc:
            sorted {
                $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedDescending
            }
        case .dateDesc:
            sorted { $0.modificationDate > $1.modificationDate }
        case .dateAsc:
            sorted { $0.modificationDate < $1.modificationDate }
        }
    }
}

struct MediaSummaryHeader: View {
    let title: String
    let itemCount: Int
    let totalSize: Int64
    let imageCount: Int
    let videoCount: Int

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text("\(itemCount) items · \(StorageFormatting.bytes(totalSize))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statPill(title: "Images", value: imageCount, systemImage: "photo")
            statPill(title: "Videos", value: videoCount, systemImage: "play.rectangle")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.bar)
    }

    private func statPill(title: String, value: Int, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(StorageFormatting.items(value))
                    .font(.callout.monospacedDigit().weight(.medium))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MediaFilterBar: View {
    @Binding var searchText: String
    @Binding var mediaFilter: MediaFilter

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
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
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            Picker("Filter", selection: $mediaFilter) {
                ForEach(MediaFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct MediaSelectionBar: View {
    let selectedCount: Int
    let selectedTotalSize: Int64
    let filteredCount: Int
    let isSelectionEmpty: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleAll) {
                HStack(spacing: 6) {
                    Image(systemName: isSelectionEmpty ? "checkmark.circle" : "xmark.circle")
                        .accessibilityHidden(true)
                    Text(isSelectionEmpty ? "Select All" : "Deselect All")
                        .font(.subheadline.weight(.medium))
                }
            }
            .buttonStyle(.plain)

            if !isSelectionEmpty {
                Divider().frame(height: 16)
                Text("\(selectedCount) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                Text(StorageFormatting.bytes(selectedTotalSize))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(filteredCount) items")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
