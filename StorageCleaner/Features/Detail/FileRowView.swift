import SwiftUI

struct FileRowView: View {
    enum PathDisplayMode {
        case parentName
        case fullPath
    }

    let url: URL
    let isSelected: Bool
    let pathDisplayMode: PathDisplayMode
    let onToggle: () -> Void
    let onPreview: (() -> Void)?

    @State private var fileExists = true
    @State private var fileSize: Int64 = 0
    @State private var modDate: Date?
    @State private var isHovering = false
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        url: URL,
        isSelected: Bool,
        pathDisplayMode: PathDisplayMode = .parentName,
        onToggle: @escaping () -> Void,
        onPreview: (() -> Void)? = nil
    ) {
        self.url = url
        self.isSelected = isSelected
        self.pathDisplayMode = pathDisplayMode
        self.onToggle = onToggle
        self.onPreview = onPreview
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Select \(url.lastPathComponent)")

            previewControl

            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(fileExists ? .primary : .secondary)

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    Text(parentDirectoryName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(pathDisplayMode == .fullPath ? 2 : 1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if fileExists {
                    Text(StorageFormatting.bytes(fileSize))
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                } else {
                    Label("Missing", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }

                if let date = modDate {
                    Text(date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .focusable(onPreview != nil)
        .focused($isFocused)
        .onKeyPress(.space) { previewFromKeyboard() }
        .onKeyPress(.return) { previewFromKeyboard() }
        .contextMenu {
            if let onPreview {
                Button("Preview", systemImage: "eye") {
                    onPreview()
                }
                Divider()
            }
            Button(isSelected ? "Deselect" : "Select", systemImage: "checkmark.circle") { onToggle() }
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .task { loadFileInfo() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var previewControl: some View {
        FileRowPreviewControl(
            url: url,
            isFocused: isFocused,
            isHovering: isHovering,
            onPreview: previewAction
        )
    }

    private var rowBackground: Color {
        if isFocused {
            return Color.accentColor.opacity(0.08)
        }
        return isHovering ? Color.accentColor.opacity(0.04) : .clear
    }

    private var parentDirectoryName: String {
        let parent = url.deletingLastPathComponent()
        if pathDisplayMode == .fullPath {
            return parent.path
        }

        let name = parent.lastPathComponent
        return name.isEmpty ? parent.path : name
    }

    private var accessibilityDescription: String {
        var parts = [url.lastPathComponent]
        if fileExists {
            parts.append(StorageFormatting.bytes(fileSize))
        } else {
            parts.append("Missing")
        }
        if let date = modDate {
            parts.append("Modified \(date.formatted(.relative(presentation: .named)))")
        }
        return parts.joined(separator: ", ")
    }

    private var previewAction: (() -> Void)? {
        guard let onPreview else { return nil }
        return {
            isFocused = true
            onPreview()
        }
    }

    private func loadFileInfo() {
        let fileManager = FileManager.default
        fileExists = fileManager.fileExists(atPath: url.path)

        if fileExists {
            let resourceKeys: [URLResourceKey] = [
                .fileAllocatedSizeKey,
                .fileSizeKey,
                .contentModificationDateKey
            ]
            let values = try? url.resourceValues(forKeys: Set(resourceKeys))
            fileSize = Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
            modDate = values?.contentModificationDate
        }
    }

    private func previewFromKeyboard() -> KeyPress.Result {
        guard let onPreview else { return .ignored }
        onPreview()
        return .handled
    }
}

private struct FileRowPreviewControl: View {
    let url: URL
    let isFocused: Bool
    let isHovering: Bool
    let onPreview: (() -> Void)?

    var body: some View {
        if let onPreview {
            Button(action: onPreview) {
                thumbnailView
            }
            .buttonStyle(.plain)
            .help("Preview \(url.lastPathComponent)")
            .accessibilityLabel("Preview \(url.lastPathComponent)")
        } else {
            iconView
        }
    }

    private var thumbnailView: some View {
        MediaThumbnailView(
            url: url,
            sideLength: 80,
            displaySideLength: 40,
            cornerRadius: 8,
            contentMode: .fill
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(thumbnailBorderColor, lineWidth: isFocused ? 2 : 1)
        }
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FileRowIconStyle.background(for: url))
                .frame(width: 36, height: 36)

            Image(systemName: FileRowIconStyle.symbol(for: url))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FileRowIconStyle.foreground(for: url))
        }
        .accessibilityHidden(true)
    }

    private var thumbnailBorderColor: Color {
        if isFocused {
            return AppTheme.accent.opacity(0.7)
        }
        return isHovering ? .secondary.opacity(0.5) : .black.opacity(0.06)
    }
}

private enum FileRowIconStyle {
    private static let symbolsByExtension: [String: String] = [
        "mov": "film.fill", "mp4": "film.fill", "m4v": "film.fill", "avi": "film.fill",
        "mkv": "film.fill", "webm": "film.fill",
        "jpg": "photo.fill", "jpeg": "photo.fill", "png": "photo.fill", "heic": "photo.fill",
        "tiff": "photo.fill", "raw": "photo.fill", "dng": "photo.fill", "gif": "photo.fill",
        "apk": "app.badge.fill", "aab": "app.badge.fill",
        "dmg": "opticaldisc.fill",
        "zip": "archivebox.fill", "tar": "archivebox.fill", "gz": "archivebox.fill",
        "7z": "archivebox.fill", "rar": "archivebox.fill",
        "log": "doc.text.fill", "crash": "doc.text.fill",
        "tmp": "doc.badge.clock.fill", "temp": "doc.badge.clock.fill",
        "mp3": "waveform", "wav": "waveform", "m4a": "waveform", "aac": "waveform", "flac": "waveform",
        "pdf": "doc.richtext.fill",
        "swift": "chevron.left.forwardslash.chevron.right",
        "py": "chevron.left.forwardslash.chevron.right",
        "js": "chevron.left.forwardslash.chevron.right",
        "ts": "chevron.left.forwardslash.chevron.right",
        "go": "chevron.left.forwardslash.chevron.right",
        "rs": "chevron.left.forwardslash.chevron.right",
        "java": "chevron.left.forwardslash.chevron.right",
        "kt": "chevron.left.forwardslash.chevron.right",
        "rb": "chevron.left.forwardslash.chevron.right"
    ]

    static func symbol(for url: URL) -> String {
        if url.hasDirectoryPath {
            return "folder.fill"
        }
        return symbolsByExtension[url.pathExtension.lowercased()] ?? "doc.fill"
    }

    static func background(for url: URL) -> Color {
        if url.hasDirectoryPath {
            return AppTheme.accent.opacity(0.12)
        }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return AppTheme.pink.opacity(0.12)
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng", "gif":
            return AppTheme.rose.opacity(0.12)
        case "apk", "aab":
            return AppTheme.orange.opacity(0.12)
        case "dmg":
            return AppTheme.violet.opacity(0.12)
        case "zip", "tar", "gz", "7z", "rar":
            return AppTheme.indigo.opacity(0.12)
        case "log", "crash", "tmp", "temp":
            return AppTheme.orange.opacity(0.12)
        case "swift", "py", "js", "ts", "go", "rs", "java", "kt", "rb":
            return AppTheme.mint.opacity(0.12)
        default:
            return .secondary.opacity(0.08)
        }
    }

    static func foreground(for url: URL) -> Color {
        if url.hasDirectoryPath {
            return AppTheme.accent
        }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return AppTheme.pink
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng", "gif":
            return AppTheme.rose
        case "apk", "aab":
            return AppTheme.orange
        case "dmg":
            return AppTheme.violet
        case "zip", "tar", "gz", "7z", "rar":
            return AppTheme.indigo
        case "log", "crash", "tmp", "temp":
            return AppTheme.orange
        case "swift", "py", "js", "ts", "go", "rs", "java", "kt", "rb":
            return AppTheme.mint
        default:
            return .secondary
        }
    }
}
