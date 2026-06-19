import Quartz
import SwiftUI

struct MediaPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            MediaPreviewContent(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))

            Divider()

            HStack(spacing: 16) {
                Label(StorageFormatting.bytes(StorageFormatting.fileSize(at: url)), systemImage: "doc")
                Label(dateString, systemImage: "clock")
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .frame(
            minWidth: 640,
            idealWidth: 880,
            maxWidth: 1_040,
            minHeight: 520,
            idealHeight: 700,
            maxHeight: 820
        )
    }

    private var dateString: String {
        let date = StorageFormatting.modificationDate(at: url)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
