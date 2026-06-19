import SwiftUI

/// One duplicate group rendered as a card: a header summarising the group and per-group actions,
/// above a horizontally scrolling strip of every copy (kept copy first).
struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    let selection: DuplicateSelectionState
    let onToggleRemoval: (URL) -> Void
    let onSetKeep: (URL) -> Void
    let onKeepBestRemoveOthers: () -> Void
    let onPreview: (URL) -> Void

    private var orderedFiles: [DuplicateFile] {
        let keepURL = selection.keepURL(for: group)
        return group.files.sorted { lhs, rhs in
            if (lhs.url == keepURL) != (rhs.url == keepURL) {
                return lhs.url == keepURL
            }
            return lhs.url.path < rhs.url.path
        }
    }

    private var markedCount: Int {
        selection.removalURLs(in: group).count
    }

    private var subtitle: String {
        let each = StorageFormatting.bytes(group.perFileBytes)
        let reclaim = StorageFormatting.bytes(group.reclaimableBytes)
        return "\(each) each · reclaim up to \(reclaim)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            header
            strip
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .cardSurface()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            Image(systemName: group.isVideo ? "film.stack.fill" : "photo.stack.fill")
                .font(.system(size: AppTheme.IconSize.sub))
                .foregroundStyle(AppTheme.indigo)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(group.files.count) identical copies")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppTheme.Spacing.medium)

            Button(action: onKeepBestRemoveOthers) {
                Label("Keep best · remove \(group.removableCount)", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Keep the recommended copy and mark every other copy in this group for removal")
        }
    }

    // MARK: - Copies strip

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.medium) {
                ForEach(orderedFiles) { file in
                    DuplicateThumbnailCell(
                        file: file,
                        isKept: selection.isKept(file.url, in: group),
                        isMarkedForRemoval: selection.isMarkedForRemoval(file.url, in: group),
                        onToggleRemoval: { onToggleRemoval(file.url) },
                        onSetKeep: { onSetKeep(file.url) },
                        onPreview: { onPreview(file.url) }
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("\(markedCount) of \(group.files.count) copies marked for removal")
    }
}
