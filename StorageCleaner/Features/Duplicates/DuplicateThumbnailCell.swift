import SwiftUI

/// One copy inside a duplicate group. The recommended copy shows a "Keep" badge and a green frame;
/// every other copy carries a removal checkbox (rose when marked) and a "Keep this instead" action.
struct DuplicateThumbnailCell: View {
    let file: DuplicateFile
    let isKept: Bool
    let isMarkedForRemoval: Bool
    let onToggleRemoval: () -> Void
    let onSetKeep: () -> Void
    let onPreview: () -> Void

    private static let side: CGFloat = 132

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            thumbnail
            caption
        }
        .frame(width: Self.side)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Preview", systemImage: "eye") { onPreview() }
            if !isKept {
                Button("Keep this copy", systemImage: "star") { onSetKeep() }
                Button(
                    isMarkedForRemoval ? "Don't remove" : "Mark for removal",
                    systemImage: isMarkedForRemoval ? "arrow.uturn.backward" : "trash"
                ) { onToggleRemoval() }
            }
            Divider()
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([file.url])
            }
        }
    }

    // MARK: - Thumbnail

    private var thumbnail: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .overlay {
                MediaThumbnailView(url: file.url, sideLength: 150, cornerRadius: 12, contentMode: .fill)
            }
            .overlay {
                if isMarkedForRemoval {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.rose.opacity(0.18))
                }
            }
            .overlay(alignment: .bottomLeading) {
                if file.isVideo { playBadge }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isKept || isMarkedForRemoval ? 2.5 : 1)
            }
            .overlay(alignment: .topLeading) { statusControl.padding(7) }
            .overlay(alignment: .topTrailing) {
                if !isKept {
                    keepButton
                        .padding(7)
                        .opacity(isHovering ? 1 : 0)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { onPreview() }
            .accessibilityAddTraits(.isButton)
            .onHover { isHovering = $0 }
            .help(isKept ? "Kept copy · click to preview" : "Click to preview · Space to Quick Look")
            .animation(.snappy(duration: 0.18), value: isMarkedForRemoval)
    }

    @ViewBuilder private var statusControl: some View {
        if isKept {
            keepBadge
        } else {
            Button(action: onToggleRemoval) {
                Image(systemName: isMarkedForRemoval ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        isMarkedForRemoval ? Color.white : Color.white,
                        isMarkedForRemoval ? AppTheme.rose : Color.black.opacity(0.35)
                    )
                    .background(Circle().fill(.black.opacity(0.08)))
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMarkedForRemoval ? "Don't remove \(file.displayName)" : "Remove \(file.displayName)")
        }
    }

    private var keepBadge: some View {
        Label("Keep", systemImage: "star.fill")
            .font(.system(size: 10, weight: .bold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(AppTheme.mint))
            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
            .accessibilityHidden(true)
    }

    private var keepButton: some View {
        Button(action: onSetKeep) {
            Image(systemName: "star")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(6)
                .background(Circle().fill(.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .help("Keep this copy instead")
        .accessibilityLabel("Keep \(file.displayName) instead")
    }

    private var playBadge: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 20))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.35))
            .shadow(color: .black.opacity(0.3), radius: 2)
            .padding(7)
            .accessibilityHidden(true)
    }

    private var borderColor: Color {
        if isKept { return AppTheme.mint }
        if isMarkedForRemoval { return AppTheme.rose }
        if isHovering { return .secondary.opacity(0.6) }
        return .black.opacity(0.06)
    }

    // MARK: - Caption

    private var caption: some View {
        VStack(spacing: 1) {
            Text(file.displayName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(file.parentName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
    }

    private var accessibilityLabel: String {
        let state = isKept ? "kept" : (isMarkedForRemoval ? "marked for removal" : "kept, not removed")
        return "\(file.displayName) in \(file.parentName), \(StorageFormatting.bytes(file.bytes)), \(state)"
    }
}
