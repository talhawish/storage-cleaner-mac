import AppKit
import AVKit
import Quartz
import SwiftUI

/// A self-contained preview renderer for a media file. The view classifies the
/// URL once and then dispatches to the right renderer:
///
/// - Raster images render in `ZoomableImageView` with pinch-to-zoom and drag-to-pan.
/// - SVGs rasterize through WebKit-backed `SVGImageRenderer`, matching thumbnails.
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
    let permissionHandler: (any StoragePermissionHandling)?

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
            ZoomableImageView(url: url, permissionHandler: permissionHandler)
        case .svg:
            SVGImagePreview(url: url, permissionHandler: permissionHandler)
        case .video:
            VideoPreviewView(url: url, permissionHandler: permissionHandler)
        case .other:
            QuickLookPreviewView(url: url, permissionHandler: permissionHandler)
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
    let permissionHandler: (any StoragePermissionHandling)?

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
        let loaded = await withPreviewAccess {
            await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
        }
        if let loaded {
            image = loaded
            loadError = false
        } else {
            loadError = true
        }
    }

    private func withPreviewAccess<T>(_ body: () async -> T) async -> T {
        guard let permissionHandler else {
            return await body()
        }
        let access = permissionHandler.beginHomeFolderAccess()
        defer { access?.stop() }
        return await body()
    }
}

// MARK: - SVG

/// Renders an SVG through the same provider used by grid/list thumbnails.
/// That keeps the full fallback chain intact: Quick Look first, native image
/// loading second, and the WebKit-backed SVG rasterizer last. Large generated
/// SVGs can be expensive for the rasterizer, while Quick Look often handles
/// them correctly.
struct SVGImagePreview: View {
    let url: URL
    let permissionHandler: (any StoragePermissionHandling)?

    @State private var image: NSImage?
    @State private var loadError = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .accessibilityLabel("Preview of \(url.lastPathComponent)")
                } else if loadError {
                    PreviewUnavailableView(
                        url: url,
                        title: "Couldn't load SVG",
                        message: "The file may be corrupt or use an unsupported SVG feature."
                    )
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .accessibilityLabel("Loading SVG preview")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .task(id: previewCacheKey(for: proxy.size)) {
                await load(for: proxy.size)
            }
        }
    }

    private func previewCacheKey(for size: CGSize) -> String {
        "\(url.path)|\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private func load(for size: CGSize) async {
        let sideLength = max(1, max(size.width, size.height))
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
        let rendered = await MediaThumbnailProvider.shared.generateThumbnail(
            for: url,
            sideLength: sideLength,
            scale: scale,
            permissionHandler: permissionHandler
        )
        guard !Task.isCancelled else { return }
        if let rendered {
            image = rendered
            loadError = false
        } else {
            image = nil
            loadError = true
        }
    }

}

// MARK: - Video

/// Thin wrapper around `AVPlayerView` so SwiftUI can host QuickTime playback
/// inside the modal. The view is intentionally read-only — the modal's action
/// bar gives the user a way to open the file in the default app or Finder.
struct VideoPreviewView: NSViewRepresentable {
    let url: URL
    let permissionHandler: (any StoragePermissionHandling)?

    func makeCoordinator() -> SecurityScopedPreviewCoordinator {
        SecurityScopedPreviewCoordinator(permissionHandler: permissionHandler)
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = true
        context.coordinator.prepareAccess(for: url)
        view.player = AVPlayer(url: url)
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player?.currentItem == nil
            || view.player?.currentItem?.asset == nil
            || (view.player?.currentItem?.asset as? AVURLAsset)?.url != url {
            context.coordinator.prepareAccess(for: url)
            view.player = AVPlayer(url: url)
        }
    }
}

// MARK: - QuickLook

struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL
    let permissionHandler: (any StoragePermissionHandling)?

    func makeCoordinator() -> SecurityScopedPreviewCoordinator {
        SecurityScopedPreviewCoordinator(permissionHandler: permissionHandler)
    }

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.autostarts = true
        context.coordinator.prepareAccess(for: url)
        previewView?.previewItem = url as NSURL
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ previewView: QLPreviewView, context: Context) {
        context.coordinator.prepareAccess(for: url)
        previewView.previewItem = url as NSURL
    }
}

final class SecurityScopedPreviewCoordinator {
    private let permissionHandler: (any StoragePermissionHandling)?
    private var access: SecurityScopedResourceAccess?
    private var accessedURL: URL?

    init(permissionHandler: (any StoragePermissionHandling)?) {
        self.permissionHandler = permissionHandler
    }

    deinit {
        access?.stop()
    }

    func prepareAccess(for url: URL) {
        guard accessedURL != url else { return }
        access?.stop()
        access = permissionHandler?.beginHomeFolderAccess()
        accessedURL = url
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
