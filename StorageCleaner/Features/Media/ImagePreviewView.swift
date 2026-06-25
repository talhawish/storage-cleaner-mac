import AppKit
import AVKit
import Quartz
import SwiftUI
import WebKit

/// A self-contained preview renderer for a media file. The view classifies the
/// URL once and then dispatches to the right renderer:
///
/// - Raster images render in `ZoomableImageView` with pinch-to-zoom and drag-to-pan.
/// - SVGs render in a transparent-background `WKWebView` so the vector stays sharp
///   at any scale.
/// - Videos render in `AVPlayerView` with the system transport controls.
/// - Anything else falls through to `QLPreviewView` so Quick Look can use its
///   built-in viewers (PDFs, Office documents, archives, etc.).
///
/// The view keeps a single thumbnail of metadata in `@State` and shows a
/// non-blocking loading indicator while the renderer initializes. The user can
/// keep navigating or close the sheet at any time without the renderer holding
/// onto its work.
struct ImagePreviewView: View {
    let url: URL
    let fileType: MediaFileType

    @State private var isLoading = true

    var body: some View {
        ZStack {
            content
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity)
                    .accessibilityLabel("Loading preview")
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { isLoading = false }
    }

    @ViewBuilder private var content: some View {
        switch fileType {
        case .rasterImage:
            ZoomableImageView(url: url)
        case .svg:
            SVGWebPreview(url: url)
        case .video:
            VideoPreviewView(url: url)
        case .other:
            QuickLookPreviewView(url: url)
        }
    }
}

// MARK: - Zoomable Image

/// A SwiftUI-native zoom/pan viewer for raster images. Loads the full image
/// once, then exposes a `magnification`/`offset` transform to the user. The
/// image is fit-to-view on first appearance and bounces back to a sane range if
/// the user pans it off-screen.
struct ZoomableImageView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var loadError: Bool = false
    @State private var zoom: CGFloat = 1
    @State private var anchorZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var anchorOffset: CGSize = .zero

    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(zoom, anchor: .center)
                        .offset(offset)
                        .gesture(magnification.simultaneously(with: drag))
                        .onTapGesture(count: 2) { reset() }
                        .accessibilityLabel("Preview of \(url.lastPathComponent)")
                } else if loadError {
                    PreviewUnavailableView(
                        url: url,
                        title: "Couldn't load image",
                        message: "The file may be corrupt or use an unsupported variant."
                    )
                } else {
                    Color.clear
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: url) { await load() }
    }

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = max(minZoom, min(maxZoom, anchorZoom * value.magnification))
            }
            .onEnded { _ in
                anchorZoom = zoom
                if zoom <= minZoom {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        zoom = minZoom
                        offset = .zero
                    }
                    anchorOffset = .zero
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: anchorOffset.width + value.translation.width,
                    height: anchorOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                anchorOffset = offset
            }
    }

    private func reset() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            zoom = minZoom
            offset = .zero
        }
        anchorZoom = minZoom
        anchorOffset = .zero
    }

    private func load() async {
        let loaded = await Task.detached(priority: .userInitiated) {
            NSImage(contentsOf: url)
        }.value
        if let loaded {
            image = loaded
            loadError = false
        } else {
            loadError = true
        }
    }
}

// MARK: - SVG

/// Renders an SVG in an off-screen `WKWebView` so the vector stays sharp at any
/// zoom level. The web view's background is forced transparent so the preview
/// blends with the modal's surface. The host page sets the SVG to fill the
/// available size, so a tall portrait SVG doesn't end up with a letterboxed
/// white square in the middle of the preview.
struct SVGWebPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        load(into: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            load(into: webView)
        }
    }

    private func load(into webView: WKWebView) {
        guard let data = try? Data(contentsOf: url),
              let markup = String(data: data, encoding: .utf8) else { return }
        let host = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8" />
        <style>
        html, body { margin: 0; padding: 0; height: 100%; width: 100%; background: transparent; }
        body { display: flex; align-items: center; justify-content: center; }
        svg { width: 100%; height: 100%; max-width: 100%; max-height: 100%; }
        </style>
        </head>
        <body>\(markup)</body>
        </html>
        """
        webView.loadHTMLString(host, baseURL: url)
    }
}

// MARK: - Video

/// Thin wrapper around `AVPlayerView` so SwiftUI can host QuickTime playback
/// inside the modal. The view is intentionally read-only — the modal's action
/// bar gives the user a way to open the file in the default app or Finder.
struct VideoPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player?.currentItem == nil
            || view.player?.currentItem?.asset == nil
            || (view.player?.currentItem?.asset as? AVURLAsset)?.url != url {
            view.player = AVPlayer(url: url)
        }
    }
}

// MARK: - QuickLook

struct QuickLookPreviewView: NSViewRepresentable {
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

// MARK: - Empty / error state

struct PreviewUnavailableView: View {
    let url: URL
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
