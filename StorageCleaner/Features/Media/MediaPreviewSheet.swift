import Quartz
import SwiftUI

struct MediaPreviewSheet: View {
    let url: URL

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        AppModal(
            idealWidth: 880,
            minHeight: 560,
            idealHeight: 700,
            maxHeight: 820
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: DependencyPaths.Media.imageExtensions.contains(url.pathExtension.lowercased())
                        ? "photo.fill"
                        : "film.fill",
                    iconTint: AppTheme.pink,
                    title: url.lastPathComponent,
                    subtitle: "Preview",
                    trailing: .sizeBadge(
                        value: StorageFormatting.bytes(StorageFormatting.fileSize(at: url)),
                        tint: AppTheme.pink
                    ),
                    showsCloseButton: true
                )

                Divider()

                MediaPreviewContent(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Show in Finder",
                            systemImage: "folder",
                            tint: AppTheme.accent,
                            isDefault: true,
                            action: {
                                NSWorkspace.shared.selectFile(
                                    nil,
                                    inFileViewerRootedAtPath: url.deletingLastPathComponent().path
                                )
                            }
                        )
                    ],
                    style: .compact
                )
            }
        }
    }
}

private struct MediaPreviewContent: View {
    let url: URL

    private var isImage: Bool {
        DependencyPaths.Media.imageExtensions.contains(url.pathExtension.lowercased())
    }

    var body: some View {
        if isImage {
            ScaledImagePreview(url: url)
        } else {
            QuickLookPreviewView(url: url)
        }
    }
}

private struct ScaledImagePreview: View {
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: proxy.size.width,
                            maxHeight: proxy.size.height,
                            alignment: .center
                        )
                        .accessibilityLabel("Preview of \(url.lastPathComponent)")
                } else {
                    UnavailablePreview(url: url)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .padding(24)
        }
    }
}

private struct UnavailablePreview: View {
    let url: URL

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Preview unavailable")
                .font(.headline)
            Text(url.lastPathComponent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.autostarts = true
        previewView?.previewItem = url as NSURL
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ previewView: QLPreviewView, context: Context) {
        previewView.previewItem = url as NSURL
    }
}
