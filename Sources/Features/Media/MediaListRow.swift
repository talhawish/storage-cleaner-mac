import SwiftUI

struct MediaListRow: View {
    let url: URL
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    @State private var thumbnail: NSImage?

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 40, height: 40)
                        .overlay { ProgressView().controlSize(.mini) }
                }

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
                    Text(StorageFormatting.bytes(StorageFormatting.fileSize(at: url)))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? AppTheme.accent : Color(white: 0.55))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Preview") { onPreview() }
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }
            Divider()
            Button("Select") { onToggle() }
        }
        .onAppear { loadThumbnail() }
    }

    private var dateString: String {
        let date = StorageFormatting.modificationDate(at: url)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func loadThumbnail() {
        Task.detached(priority: .utility) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            let size = NSSize(width: 64, height: 64)
            img.size = size
            await MainActor.run { self.thumbnail = img }
        }
    }
}
