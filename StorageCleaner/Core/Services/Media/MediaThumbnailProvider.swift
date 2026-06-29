import AppKit
import Foundation
import QuickLookThumbnailing

/// Produces square thumbnails for the media grid and list rows. The provider is a
/// shared actor with its own in-memory `NSCache`, so a view scrolling through a
/// large grid only generates each thumbnail once for the lifetime of the process.
///
/// The fallback chain is:
/// 1. **QuickLook** for any file the system can render a thumbnail for (most
///    images, PDFs, videos, archives, etc.). Fast and respects macOS-level codec
///    support.
/// 2. **`NSImage(contentsOf:)`** for cases where QuickLook returned nil. This
///    catches some HEIC variants, screen recordings whose first-frame still
///    hasn't been written yet, and similar edge cases.
/// 3. **SVG rasterization** via `SVGImageRenderer` for `.svg` files. Required
///    because QuickLook returns nil for many SVGs and `NSImage(contentsOf:)`
///    is unreliable for vector content.
actor MediaThumbnailProvider {
    static let shared = MediaThumbnailProvider()

    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(
        for url: URL,
        sideLength: CGFloat,
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) async -> NSImage? {
        let scale = await screenScale()
        let pixelSize = Int((sideLength * scale).rounded())
        let key = "\(url.path)|\(pixelSize)" as NSString

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard let image = await generateThumbnail(
            for: url,
            sideLength: sideLength,
            scale: scale,
            permissionHandler: permissionHandler
        ) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    /// Public so tests can exercise the chain without going through the cache.
    func generateThumbnail(
        for url: URL,
        sideLength: CGFloat,
        scale: CGFloat,
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) async -> NSImage? {
        await withPreviewAccess(permissionHandler) {
            await generateThumbnailWithoutAccessManagement(for: url, sideLength: sideLength, scale: scale)
        }
    }

    private func generateThumbnailWithoutAccessManagement(
        for url: URL,
        sideLength: CGFloat,
        scale: CGFloat
    ) async -> NSImage? {
        if let image = await quickLookThumbnail(for: url, sideLength: sideLength, scale: scale) {
            return image
        }
        if let image = await nativeImageThumbnail(for: url) {
            return image
        }
        if MediaFileType.classify(url: url).isSVG {
            return await SVGImageRenderer.shared.rasterize(url: url, sideLength: sideLength, scale: scale)
        }
        return nil
    }

    private func withPreviewAccess<T>(
        _ permissionHandler: (any StoragePermissionHandling)?,
        _ body: () async -> T
    ) async -> T {
        guard let permissionHandler else {
            return await body()
        }
        let access = permissionHandler.beginHomeFolderAccess()
        defer { access?.stop() }
        return await body()
    }

    private func quickLookThumbnail(for url: URL, sideLength: CGFloat, scale: CGFloat) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: sideLength, height: sideLength),
            scale: scale,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                continuation.resume(returning: thumbnail?.nsImage)
            }
        }
    }

    private func nativeImageThumbnail(for url: URL) async -> NSImage? {
        await Task.detached(priority: .utility) {
            NSImage(contentsOf: url)
        }.value
    }

    private func screenScale() async -> CGFloat {
        await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2
        }
    }
}
