import SwiftUI

/// Media-type filter for the Duplicates screen.
enum DuplicateMediaFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"

    var id: Self { self }

    /// The finding kinds shown for this filter.
    var kinds: [StorageFindingKind] {
        switch self {
        case .all: [.duplicatePhotos, .duplicateVideos]
        case .photos: [.duplicatePhotos]
        case .videos: [.duplicateVideos]
        }
    }
}

/// Sticky header: totals, media-type filter, bulk selection controls, and the primary remove action.
struct DuplicatesSummaryHeader: View {
    let groupCount: Int
    let copyCount: Int
    let totalReclaimableBytes: Int64
    let selectedCount: Int
    let selectedBytes: Int64
    @Binding var filter: DuplicateMediaFilter
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onReset: () -> Void
    let onRemoveSelected: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.mediumLarge) {
                stat(value: "\(groupCount)", label: groupCount == 1 ? "group" : "groups")
                stat(value: "\(copyCount)", label: "duplicate copies")
                stat(value: StorageFormatting.bytes(totalReclaimableBytes), label: "reclaimable")

                Spacer(minLength: AppTheme.Spacing.medium)

                Picker("Filter", selection: $filter) {
                    ForEach(DuplicateMediaFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            HStack(spacing: AppTheme.Spacing.small) {
                Menu {
                    Button("Select all duplicates", systemImage: "checkmark.circle", action: onSelectAll)
                    Button("Deselect all", systemImage: "circle", action: onDeselectAll)
                    Divider()
                    Button("Reset to recommended", systemImage: "arrow.counterclockwise", action: onReset)
                } label: {
                    Label("Selection", systemImage: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                if selectedCount > 0 {
                    Text("\(selectedCount) selected · \(StorageFormatting.bytes(selectedBytes))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                Button(role: .destructive, action: onRemoveSelected) {
                    Label("Remove \(selectedCount) duplicates", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.rose)
                .disabled(selectedCount == 0)
                .keyboardShortcut(.delete, modifiers: [.command])
            }
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.hairline).frame(height: 1)
        }
        .animation(.snappy(duration: 0.18), value: selectedCount)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
