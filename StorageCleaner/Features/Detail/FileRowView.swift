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

    @State private var fileExists = true
    @State private var fileSize: Int64 = 0
    @State private var modDate: Date?
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        url: URL,
        isSelected: Bool,
        pathDisplayMode: PathDisplayMode = .parentName,
        onToggle: @escaping () -> Void
    ) {
        self.url = url
        self.isSelected = isSelected
        self.pathDisplayMode = pathDisplayMode
        self.onToggle = onToggle
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

            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(fileExists ? .primary : .secondary)

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        .background(isHovering ? Color.accentColor.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .task { loadFileInfo() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconBackground)
                .frame(width: 36, height: 36)

            Image(systemName: iconForURL)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
        .accessibilityHidden(true)
    }

    private var parentDirectoryName: String {
        let parent = url.deletingLastPathComponent()
        if pathDisplayMode == .fullPath {
            return parent.path
        }

        let name = parent.lastPathComponent
        return name.isEmpty ? parent.path : name
    }

    private var iconForURL: String {
        if url.hasDirectoryPath {
            return "folder.fill"
        }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            return "film.fill"
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng", "gif":
            return "photo.fill"
        case "apk", "aab":
            return "app.badge.fill"
        case "dmg":
            return "opticaldisc.fill"
        case "zip", "tar", "gz", "7z", "rar":
            return "archivebox.fill"
        case "log", "crash":
            return "doc.text.fill"
        case "tmp", "temp":
            return "doc.badge.clock.fill"
        case "mp3", "wav", "m4a", "aac", "flac":
            return "waveform"
        case "pdf":
            return "doc.richtext.fill"
        case "swift", "py", "js", "ts", "go", "rs", "java", "kt", "rb":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    private var iconBackground: Color {
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

    private var iconForeground: Color {
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
}
