import SwiftUI

struct MediaGridItem: View {
    let url: URL
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    @State private var isHovering = false

    private var isVideo: Bool {
        DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased())
    }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary.opacity(0.4))
                        .aspectRatio(1, contentMode: .fit)

                    MediaThumbnailView(
                        url: url,
                        sideLength: 180,
                        cornerRadius: 10,
                        contentMode: .fill
                    )

                    if isVideo {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.shadow(.drop(radius: 2)))
                                    .accessibilityHidden(true)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }

                    VStack {
                        HStack {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.accent, .white)
                                    .accessibilityHidden(true)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isSelected ? AppTheme.accent : (isHovering ? Color.secondary : .clear),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .onHover { isHovering = $0 }

                VStack(spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                    Text(StorageFormatting.bytes(StorageFormatting.fileSize(at: url)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
    }
}
