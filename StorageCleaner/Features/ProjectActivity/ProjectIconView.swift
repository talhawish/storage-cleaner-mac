import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Shows a project's real icon/logo when one was found, falling back to the
/// technology's tinted SF Symbol otherwise. The bitmap is downsampled off the
/// main actor so a grid of projects never blocks the UI.
struct ProjectIconView: View {
    let iconURL: URL?
    let technology: ProjectTechnology
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 10

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: technology.color).opacity(0.12))

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .accessibilityHidden(true)
            } else {
                Image(systemName: technology.symbolName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(Color(hex: technology.color))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: iconURL) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let iconURL else {
            thumbnail = nil
            return
        }
        let pixelSize = Int(size * 2)
        let data = await Task.detached(priority: .utility) {
            ProjectThumbnailLoader.pngThumbnail(for: iconURL, maxPixelSize: pixelSize)
        }.value
        guard !Task.isCancelled, let data else { return }
        thumbnail = NSImage(data: data)
    }
}

/// Downsamples an image file to a small PNG using ImageIO. Returns `Data`
/// (Sendable) so the work can run off the main actor; `nil` for formats ImageIO
/// can't decode (e.g. SVG).
enum ProjectThumbnailLoader {
    static func pngThumbnail(for url: URL, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(8, maxPixelSize)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
