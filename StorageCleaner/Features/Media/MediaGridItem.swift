import SwiftUI

struct MediaGridItem: View {
    let url: URL
    let isSelected: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    private var isVideo: Bool {
        DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased())
    }

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
            caption
        }
        .focusable()
        .focused($isFocused)
        .onKeyPress(.space) { onPreview(); return .handled }
        .onKeyPress(.return) { onPreview(); return .handled }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(url.lastPathComponent), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Preview", systemImage: "eye") { onPreview() }
            Button(isSelected ? "Deselect" : "Select", systemImage: "checkmark.circle") { onToggle() }
            Divider()
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                MediaThumbnailView(
                    url: url,
                    sideLength: 150,
                    cornerRadius: 10,
                    contentMode: .fill
                )
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.14))
                }
            }
            .overlay(alignment: .bottomLeading) {
                if isVideo { playBadge }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture {
                isFocused = true
                onPreview()
            }
            .accessibilityAddTraits(.isButton)
            // Selection control sits on top so its taps don't open the preview.
            .overlay(alignment: .topLeading) {
                selectionToggle
                    .padding(7)
                    .opacity(isSelected || isHovering ? 1 : 0)
            }
            .onHover { isHovering = $0 }
            .help("Click to preview · Space to Quick Look")
    }

    private var selectionToggle: some View {
        Button(action: onToggle) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    isSelected ? Color.white : Color.white,
                    isSelected ? AppTheme.accent : Color.black.opacity(0.35)
                )
                .background(Circle().fill(.black.opacity(0.08)))
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Deselect \(url.lastPathComponent)" : "Select \(url.lastPathComponent)")
    }

    private var playBadge: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 22))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.35))
            .shadow(color: .black.opacity(0.3), radius: 2)
            .padding(7)
            .accessibilityHidden(true)
    }

    private var borderColor: Color {
        if isSelected { return AppTheme.accent }
        if isFocused { return AppTheme.accent.opacity(0.6) }
        if isHovering { return .secondary.opacity(0.6) }
        return .black.opacity(0.06)
    }

    // MARK: - Caption

    private var caption: some View {
        VStack(spacing: 1) {
            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(StorageFormatting.bytes(StorageFormatting.fileSize(at: url)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
