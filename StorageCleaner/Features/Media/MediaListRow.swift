import SwiftUI

struct MediaListRow: View {
    let url: URL
    let size: Int64
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void
    let permissionHandler: (any StoragePermissionHandling)?
    var canRevealInFinder = true

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                MediaThumbnailView(
                    url: url,
                    sideLength: 64,
                    displaySideLength: 40,
                    cornerRadius: 6,
                    contentMode: .fill,
                    permissionHandler: permissionHandler
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.callout)
                        .lineLimit(1)
                    Text(url.deletingLastPathComponent().lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(StorageFormatting.bytes(size))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? AppTheme.accent : Color(white: 0.55))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Preview") { onPreview() }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
            .disabled(!canRevealInFinder)
            Divider()
            Button("Select") { onToggle() }
        }
    }

    private var dateString: String {
        let date = StorageFormatting.modificationDate(at: url)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

}
