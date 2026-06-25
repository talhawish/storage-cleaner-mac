import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// A snapshot of the metadata we surface in the preview sheet header: the image's
/// pixel dimensions, color space, bit depth, and (when available) the EXIF
/// capture date. Returned as a value type so the sheet can render it on the main
/// actor without any further thread hops.
struct ImageMetadata: Equatable, Sendable {
    let pixelWidth: Int
    let pixelHeight: Int
    let colorSpaceName: String?
    let bitDepth: Int?
    let hasAlpha: Bool
    let creationDate: Date?
    let orientation: Int

    static let unknown = ImageMetadata(
        pixelWidth: 0,
        pixelHeight: 0,
        colorSpaceName: nil,
        bitDepth: nil,
        hasAlpha: false,
        creationDate: nil,
        orientation: 1
    )

    var isKnown: Bool { pixelWidth > 0 && pixelHeight > 0 }

    var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    /// Human-readable dimensions, e.g. "3024 × 1964". Falls back to "Unknown" when
    /// the source has no resolvable pixel size (e.g. some SVG variants).
    var dimensionsDescription: String {
        guard isKnown else { return "Unknown dimensions" }
        return "\(pixelWidth) × \(pixelHeight)"
    }

    /// Aspect ratio as a `width:height` string (e.g. "16:9"), useful for the header
    /// pill. Returns nil when the dimensions are unknown or not in a clean ratio.
    var aspectRatioDescription: String? {
        guard isKnown, pixelWidth > 0, pixelHeight > 0 else { return nil }
        let divisor = gcd(pixelWidth, pixelHeight)
        let widthRatio = pixelWidth / divisor
        let heightRatio = pixelHeight / divisor
        return "\(widthRatio):\(heightRatio)"
    }

    private func gcd(_ first: Int, _ second: Int) -> Int {
        var lhs = first
        var rhs = second
        while rhs != 0 {
            (lhs, rhs) = (rhs, lhs % rhs)
        }
        return max(lhs, 1)
    }
}

enum ImageMetadataLoader {
    /// Read the metadata for `url` off the main thread. Returns `.unknown` for
    /// unreadable files and a populated value for everything else. Safe to call
    /// from any actor.
    static func load(for url: URL) async -> ImageMetadata {
        await Task.detached(priority: .utility) {
            loadSync(for: url)
        }.value
    }

    /// Synchronous variant, used by tests and the detached task above. Reads the
    /// file with `ImageIO` so we get the on-disk pixel dimensions, color profile,
    /// bit depth, and EXIF creation date in a single pass.
    static func loadSync(for url: URL) -> ImageMetadata {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return svgFallback(for: url)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return svgFallback(for: url)
        }
        return metadata(from: properties, fallbackURL: url)
    }

    private static func metadata(from properties: [CFString: Any], fallbackURL: URL) -> ImageMetadata {
        let width = (properties[kCGImagePropertyPixelWidth] as? Int)
            ?? Int((properties[kCGImagePropertyPixelWidth] as? Double) ?? 0)
        let height = (properties[kCGImagePropertyPixelHeight] as? Int)
            ?? Int((properties[kCGImagePropertyPixelHeight] as? Double) ?? 0)
        let depth = properties[kCGImagePropertyDepth] as? Int
        let hasAlpha = (properties[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let orientation = (properties[kCGImagePropertyOrientation] as? Int) ?? 1
        let colorModel = properties[kCGImagePropertyColorModel] as? String
        let profileName = properties[kCGImagePropertyProfileName] as? String

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let creation = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        let parsedDate = creation.flatMap(parseEXIFDate)

        if width > 0, height > 0 {
            return ImageMetadata(
                pixelWidth: width,
                pixelHeight: height,
                colorSpaceName: profileName ?? colorModel,
                bitDepth: depth,
                hasAlpha: hasAlpha,
                creationDate: parsedDate,
                orientation: orientation
            )
        }
        return svgFallback(for: fallbackURL)
    }

    /// SVG and other formats ImageIO can't decode fall back to parsing the file
    /// directly for the embedded `width`/`height`/`viewBox` attributes.
    private static func svgFallback(for url: URL) -> ImageMetadata {
        guard url.pathExtension.lowercased() == "svg",
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return .unknown
        }
        let width = svgDimension(in: raw, attribute: "width")
        let height = svgDimension(in: raw, attribute: "height")
        let viewBox = svgViewBox(in: raw)

        let resolvedWidth: Int = width ?? viewBox?.width ?? 0
        let resolvedHeight: Int = height ?? viewBox?.height ?? 0

        guard resolvedWidth > 0, resolvedHeight > 0 else { return .unknown }
        return ImageMetadata(
            pixelWidth: resolvedWidth,
            pixelHeight: resolvedHeight,
            colorSpaceName: "sRGB",
            bitDepth: 32,
            hasAlpha: true,
            creationDate: nil,
            orientation: 1
        )
    }

    private static func svgDimension(in svg: String, attribute: String) -> Int? {
        let pattern = "\(attribute)\\s*=\\s*\"([0-9.]+)(?:px)?\""
        guard let match = svg.range(of: pattern, options: .regularExpression) else { return nil }
        let substring = svg[match].components(separatedBy: "\"").dropFirst().first ?? ""
        if let raw = Double(substring.trimmingCharacters(in: .whitespaces)) {
            return Int(raw.rounded())
        }
        return nil
    }

    private struct ViewBox {
        let width: Int
        let height: Int
    }

    private static func svgViewBox(in svg: String) -> ViewBox? {
        let pattern = "viewBox\\s*=\\s*\"\\s*[0-9.\\-]+\\s+[0-9.\\-]+\\s+([0-9.]+)\\s+([0-9.]+)"
        guard let match = svg.range(of: pattern, options: .regularExpression) else { return nil }
        let captures = svg[match].components(separatedBy: "\"")
        let numbers = captures.dropFirst().first?
            .split(separator: " ")
            .compactMap { Double($0) } ?? []
        guard numbers.count == 4 else { return nil }
        return ViewBox(width: Int(numbers[2].rounded()), height: Int(numbers[3].rounded()))
    }

    private static func parseEXIFDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}
