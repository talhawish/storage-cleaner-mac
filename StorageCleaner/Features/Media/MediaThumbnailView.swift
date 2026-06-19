import QuickLookThumbnailing
import SwiftUI

struct MediaThumbnailView: View {
    let url: URL
    let sideLength: CGFloat
    let displaySideLength: CGFloat?
    let cornerRadius: CGFloat
    let contentMode: ContentMode

    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    init(
        url: URL,
        sideLength: CGFloat,
        displaySideLength: CGFloat? = nil,
        cornerRadius: CGFloat,
        contentMode: ContentMode
    ) {
        self.url = url
        self.sideLength = sideLength
        self.displaySideLength = displaySideLength
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
    }

    /// When `displaySideLength` is set the view is a fixed square (list rows).
    /// When nil it fills its container so a parent can enforce a square crop (grid).
    private var fillsContainer: Bool { displaySideLength == nil }

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.quaternary.opacity(0.45))
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: fallbackSystemImage)
                                .font(.system(size: sideLength * 0.28))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
        .frame(width: displaySideLength, height: displaySideLength)
        .frame(
            maxWidth: fillsContainer ? .infinity : nil,
            maxHeight: fillsContainer ? .infinity : nil
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            isLoading = true
            thumbnail = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: sideLength)
            isLoading = false
        }
        .accessibilityHidden(true)
    }

    private var fallbackSystemImage: String {
        DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased())
            ? "film"
            : "photo"
    }
}

actor MediaThumbnailProvider {
    static let shared = MediaThumbnailProvider()

    private let cache = NSCache<NSString, NSImage>()

    func thumbnail(for url: URL, sideLength: CGFloat) async -> NSImage? {
        let scale = await screenScale()
        let pixelSize = Int(sideLength * scale)
        let key = "\(url.path)|\(pixelSize)" as NSString

        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard let image = await generateThumbnail(for: url, sideLength: sideLength) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }

    private func generateThumbnail(for url: URL, sideLength: CGFloat) async -> NSImage? {
        let scale = await screenScale()
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

    private func screenScale() async -> CGFloat {
        await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2
        }
    }
}
