import AppKit
import SwiftUI

/// Modal preview for a media file. Composes a header (file name, type, size,
/// dimensions, color profile, modified date, full path) with a body that
/// dispatches to `ImagePreviewView` for the actual content. The action bar
/// exposes the most common next steps: open in Finder, reveal in Finder's
/// containing folder, open with the system default app, and copy the path.
struct MediaPreviewSheet: View {
    let url: URL

    @Environment(\.dismiss)
    private var dismiss

    @State private var fileType: MediaFileType
    @State private var imageMetadata: ImageMetadata = .unknown
    @State private var bytes: Int64 = 0
    @State private var modifiedAt: Date?
    @State private var showCopiedFeedback = false
    @State private var copyFeedbackTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        _fileType = State(initialValue: MediaFileType.classify(url: url))
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        AppModal(
            idealWidth: 920,
            minHeight: 600,
            idealHeight: 760,
            maxHeight: 880
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: fileType.symbolName,
                    iconTint: headerTint,
                    title: url.lastPathComponent,
                    subtitle: subtitle,
                    trailing: .custom(
                        AnyView(PreviewHeaderBadges(
                            fileType: fileType,
                            metadata: imageMetadata,
                            bytes: bytes
                        ))
                    ),
                    showsCloseButton: true
                )

                Divider()

                ImagePreviewView(url: url, fileType: fileType)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                PreviewMetadataStrip(
                    metadata: imageMetadata,
                    bytes: bytes,
                    modifiedAt: modifiedAt,
                    fileExists: fileExists
                )

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: actions,
                    style: .compact
                )
            }
        }
        .task(id: url) { await loadMetadata() }
    }

    private var subtitle: String {
        if !fileExists {
            return "Missing file"
        }
        return fileType.displayName
    }

    private var headerTint: Color {
        switch fileType {
        case .rasterImage, .svg: return AppTheme.pink
        case .video: return AppTheme.violet
        case .other(let kind):
            switch kind {
            case .pdf, .document: return AppTheme.accent
            case .archive: return AppTheme.indigo
            case .installer: return AppTheme.orange
            case .audio: return AppTheme.mint
            case .font: return AppTheme.teal
            case .executable: return AppTheme.rose
            case .binary: return AppTheme.amber
            }
        }
    }

    private var actions: [AppModalActionBar.Action] {
        var result: [AppModalActionBar.Action] = [
            AppModalActionBar.Action(
                title: showCopiedFeedback ? "Copied" : "Copy Path",
                systemImage: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc",
                tint: showCopiedFeedback ? AppTheme.mint : AppTheme.accent,
                isProminent: false,
                isDefault: false,
                action: copyPath
            ),
            AppModalActionBar.Action(
                title: "Show in Finder",
                systemImage: "folder",
                tint: AppTheme.accent,
                isProminent: false,
                isDefault: true,
                action: showInFinder
            )
        ]
        if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
            result.append(
                AppModalActionBar.Action(
                    title: "Open",
                    systemImage: "arrow.up.right.square",
                    tint: AppTheme.accent,
                    isProminent: true,
                    isDefault: false,
                    action: openWithDefaultApp
                )
            )
        }
        return result
    }

    private func loadMetadata() async {
        async let metadata = ImageMetadataLoader.load(for: url)
        let resolvedMetadata = await metadata
        let size = StorageFormatting.fileSize(at: url)
        let modification = StorageFormatting.modificationDate(at: url)
        imageMetadata = resolvedMetadata
        bytes = size
        modifiedAt = modification
    }

    private func copyPath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        showCopiedFeedback = true
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            showCopiedFeedback = false
        }
    }

    private func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openWithDefaultApp() {
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Header badges

/// The two pills in the trailing slot of the modal header: the type on the left
/// and the byte size on the right. The size is the same `StorageFormatting.bytes`
/// string we use everywhere else so the look matches.
private struct PreviewHeaderBadges: View {
    let fileType: MediaFileType
    let metadata: ImageMetadata
    let bytes: Int64

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(fileType.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(StorageFormatting.bytes(bytes))
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Metadata strip

/// The row of metadata pills above the action bar. Pills are always laid out
/// in the same order so the rhythm matches across all previews: type badge,
/// dimensions, color space, modified date. Missing values are omitted
/// individually so an unknown dimension doesn't take a pill width.
private struct PreviewMetadataStrip: View {
    let metadata: ImageMetadata
    let bytes: Int64
    let modifiedAt: Date?
    let fileExists: Bool

    private var dateFormatStyle: Date.FormatStyle {
        .dateTime
            .year()
            .month(.abbreviated)
            .day()
            .hour()
            .minute()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if !fileExists {
                MetadataPill(
                    icon: "exclamationmark.triangle.fill",
                    tint: .red,
                    text: "Missing"
                )
            }

            if metadata.isKnown {
                MetadataPill(
                    icon: "ruler",
                    tint: AppTheme.accent,
                    text: metadata.dimensionsDescription
                )
                if let aspect = metadata.aspectRatioDescription {
                    MetadataPill(
                        icon: "aspectratio",
                        tint: AppTheme.cyan,
                        text: aspect
                    )
                }
                if let colorSpace = metadata.colorSpaceName {
                    MetadataPill(
                        icon: "paintpalette",
                        tint: AppTheme.violet,
                        text: colorSpace
                    )
                }
            }

            if let depth = metadata.bitDepth {
                MetadataPill(
                    icon: "square.stack.3d.up",
                    tint: AppTheme.amber,
                    text: "\(depth)-bit"
                )
            }

            if let modifiedAt {
                MetadataPill(
                    icon: "clock",
                    tint: .gray,
                    text: modifiedAt.formatted(dateFormatStyle)
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

private struct MetadataPill: View {
    let icon: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }
}
