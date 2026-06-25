import AppKit
import Foundation
import WebKit

/// Rasterizes SVG files to `NSImage` at a requested pixel size using an off-screen
/// `WKWebView`. Apple's built-in `NSImage(contentsOf:)` SVG support is inconsistent
/// (it returns nil for many SVGs and reports unreliable intrinsic sizes on the ones
/// it does load), so the only faithful approach is to drive the WebKit layout engine
/// directly.
///
/// The renderer is an actor that owns a small pool of `WKWebView` entries keyed by
/// pixel size, so a view scrolling through a long grid of SVG thumbnails only spins
/// up a handful of pages total instead of one per visible cell. Each cell loads its
/// markup, waits for the layout to settle, snapshots the view, and reuses the same
/// web view for the next request.
actor SVGImageRenderer {
    static let shared = SVGImageRenderer()

    private var pool: [Int: PoolEntry] = [:]
    private let maximumPoolSize = 3

    func rasterize(url: URL, sideLength: CGFloat, scale: CGFloat) async -> NSImage? {
        let pixelSide = max(1, Int((sideLength * scale).rounded()))
        guard let markup = await loadMarkup(for: url) else { return nil }
        return await rasterize(markup: markup, baseURL: url, pixelSide: pixelSide)
    }

    func rasterizeDirect(svgData: Data, sideLength: CGFloat, scale: CGFloat) async -> NSImage? {
        let pixelSide = max(1, Int((sideLength * scale).rounded()))
        guard let markup = String(data: svgData, encoding: .utf8) else { return nil }
        return await rasterize(markup: markup, baseURL: nil, pixelSide: pixelSide)
    }

    private func rasterize(markup: String, baseURL: URL?, pixelSide: Int) async -> NSImage? {
        guard let entry = await acquireEntry(for: pixelSide) else { return nil }
        return await entry.load(markup: markup, baseURL: baseURL)
    }

    private func loadMarkup(for url: URL) async -> String? {
        await Task.detached(priority: .utility) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return String(data: data, encoding: .utf8)
        }.value
    }

    private func acquireEntry(for pixelSide: Int) async -> PoolEntry? {
        if let existing = pool[pixelSide] {
            await existing.touch()
            return existing
        }

        if pool.count >= maximumPoolSize {
            let snapshot = pool
            if let victimPixelSide = await leastRecentlyUsedPixelSide(in: snapshot) {
                pool.removeValue(forKey: victimPixelSide)
                if let victim = pool[victimPixelSide] {
                    await victim.dispose()
                } else if let stale = snapshot[victimPixelSide] {
                    await stale.dispose()
                }
            }
        }

        guard let entry = await PoolEntry(pixelSide: pixelSide) else { return nil }
        pool[pixelSide] = entry
        return entry
    }

    private func leastRecentlyUsedPixelSide(in pool: [Int: PoolEntry]) async -> Int? {
        guard !pool.isEmpty else { return nil }
        var oldestKey: Int?
        var oldestDate: Date = .distantFuture
        for (key, entry) in pool {
            let used = await entry.lastUsed
            if used < oldestDate {
                oldestDate = used
                oldestKey = key
            }
        }
        return oldestKey
    }
}

/// One `WKWebView` for a given pixel-size bucket. The entry is `@MainActor` because
/// `WKWebView` requires main-actor isolation, but the snapshot it produces is itself
/// `Sendable` so callers on any actor can read the result.
@MainActor
private final class PoolEntry: NSObject, WKNavigationDelegate, @unchecked Sendable {
    let pixelSide: Int
    private let webView: WKWebView
    private var hasFinishedLoad = true
    fileprivate var lastUsed = Date()
    private var pendingTimeout: DispatchWorkItem?
    private var pendingContinuation: CheckedContinuation<NSImage?, Never>?
    private var pendingTimeoutFired = false

    init?(pixelSide: Int) {
        self.pixelSide = pixelSide
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        let frame = NSRect(x: 0, y: 0, width: CGFloat(pixelSide), height: CGFloat(pixelSide))
        let view = WKWebView(frame: frame, configuration: configuration)
        self.webView = view
        super.init()
        view.navigationDelegate = self
    }

    func touch() {
        lastUsed = Date()
    }

    func load(markup: String, baseURL: URL?) async -> NSImage? {
        cancelTimeout()
        hasFinishedLoad = false
        pendingTimeoutFired = false
        let html = Self.hostedHTML(for: markup, sideLength: pixelSide)
        webView.loadHTMLString(html, baseURL: baseURL)
        startTimeout()
        return await withCheckedContinuation { (continuation: CheckedContinuation<NSImage?, Never>) in
            self.pendingContinuation = continuation
        }
    }

    func dispose() {
        cancelTimeout()
        webView.navigationDelegate = nil
        webView.stopLoading()
    }

    private func cancelTimeout() {
        pendingTimeout?.cancel()
        pendingTimeout = nil
    }

    private func startTimeout() {
        let item = DispatchWorkItem { [weak self] in
            self?.fireTimeout()
        }
        pendingTimeout = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800), execute: item)
    }

    private func fireTimeout() {
        guard !hasFinishedLoad, !pendingTimeoutFired else { return }
        pendingTimeoutFired = true
        finish(with: nil)
    }

    private func finish(with image: NSImage?) {
        cancelTimeout()
        guard !hasFinishedLoad else { return }
        hasFinishedLoad = true
        let continuation = pendingContinuation
        pendingContinuation = nil
        continuation?.resume(returning: image)
    }

    /// Wrap the SVG markup in a minimal HTML host that scales it to fill a fixed-size
    /// square. Setting `width`/`height` on the `<svg>` itself is unreliable because
    /// many files use viewBox-only sizing; the wrapper forces the viewport to match
    /// the requested pixel size so the snapshot has a predictable bitmap dimension.
    private static func hostedHTML(for svg: String, sideLength: Int) -> String {
        let body = sanitizedBody(from: svg)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8" />
        <style>
        html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
        body { width: \(sideLength)px; height: \(sideLength)px; }
        svg { width: \(sideLength)px; height: \(sideLength)px; display: block; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func sanitizedBody(from svg: String) -> String {
        if svg.range(of: "<svg[\\s>]", options: .regularExpression) != nil {
            return svg
        }
        return "<div>Invalid SVG</div>"
    }

    // MARK: WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            await self?.captureSnapshot(of: webView)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in self?.finish(with: nil) }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor [weak self] in self?.finish(with: nil) }
    }

    private func captureSnapshot(of webView: WKWebView) async {
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = true
        let image: NSImage? = await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: configuration) { snapshotImage, _ in
                continuation.resume(returning: snapshotImage)
            }
        }
        finish(with: image)
    }
}
