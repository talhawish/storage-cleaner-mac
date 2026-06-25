import Foundation

/// Centralized classification of media files for the preview sheet and thumbnail
/// provider. Every preview entry point asks `MediaFileType.classify(url:)` and then
/// branches on the resulting case so the same classification logic powers the
/// thumbnail fallback chain, the header metadata pills, and the picker of
/// renderers in `MediaPreviewSheet`.
enum MediaFileType: Equatable, Sendable {
    case rasterImage(format: RasterImageFormat)
    case svg
    case video
    case other(kind: OtherKind)

    enum RasterImageFormat: String, Sendable, CaseIterable {
        case png
        case jpeg
        case gif
        case bmp
        case tiff
        case webp
        case heic
        case heif
        case raw
        case dng
        case other

        var displayName: String {
            switch self {
            case .png: "PNG"
            case .jpeg: "JPEG"
            case .gif: "GIF"
            case .bmp: "BMP"
            case .tiff: "TIFF"
            case .webp: "WebP"
            case .heic: "HEIC"
            case .heif: "HEIF"
            case .raw: "RAW"
            case .dng: "DNG"
            case .other: "Image"
            }
        }
    }

    enum OtherKind: String, Sendable {
        case document
        case archive
        case installer
        case audio
        case pdf
        case font
        case executable
        case binary

        var displayName: String {
            switch self {
            case .document: "Document"
            case .archive: "Archive"
            case .installer: "Installer"
            case .audio: "Audio"
            case .pdf: "PDF"
            case .font: "Font"
            case .executable: "Executable"
            case .binary: "File"
            }
        }
    }

    static func classify(url: URL) -> MediaFileType {
        let ext = url.pathExtension.lowercased()
        if let format = rasterFormat(for: ext) {
            return .rasterImage(format: format)
        }
        if DependencyPaths.Media.vectorImageExtensions.contains(ext) {
            return .svg
        }
        if DependencyPaths.Media.videoExtensions.contains(ext) {
            return .video
        }
        return classifyOther(extension: ext)
    }

    private static func classifyOther(extension ext: String) -> MediaFileType {
        if Self.archiveExtensions.contains(ext) {
            return .other(kind: .archive)
        }
        if DependencyPaths.Documents.documentExtensions.contains(ext) {
            return .other(kind: ext == "pdf" ? .pdf : .document)
        }
        if DependencyPaths.Leftovers.installerExtensions.contains(ext)
            || DependencyPaths.Leftovers.androidPackageExtensions.contains(ext) {
            return .other(kind: .installer)
        }
        if Self.audioExtensions.contains(ext) {
            return .other(kind: .audio)
        }
        if Self.fontExtensions.contains(ext) {
            return .other(kind: .font)
        }
        if Self.executableExtensions.contains(ext) {
            return .other(kind: .executable)
        }
        return .other(kind: .binary)
    }

    /// Compressed-archive formats. Kept separate from `Documents.documentExtensions`
    /// so the preview surface can show a distinct icon and header for zip/tar/etc.
    /// even though the duplicate-document scanner treats them as documents.
    private static let archiveExtensions: Set<String> = [
        "zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz", "zst", "7z", "rar"
    ]

    private static let audioExtensions: Set<String> = [
        "mp3", "wav", "m4a", "aac", "flac", "aiff", "ogg"
    ]

    private static let fontExtensions: Set<String> = [
        "ttf", "otf", "woff", "woff2"
    ]

    private static let executableExtensions: Set<String> = [
        "app", "exe", "bat", "sh", "command"
    ]

    var isImage: Bool {
        switch self {
        case .rasterImage, .svg: return true
        case .video, .other: return false
        }
    }

    var isSVG: Bool {
        if case .svg = self { return true }
        return false
    }

    var isVideo: Bool {
        if case .video = self { return true }
        return false
    }

    var displayName: String {
        switch self {
        case let .rasterImage(format): return format.displayName
        case .svg: return "SVG"
        case .video: return "Video"
        case let .other(kind): return kind.displayName
        }
    }

    /// Symbol used in the preview header and fallback placeholders.
    var symbolName: String {
        switch self {
        case .rasterImage: "photo.fill"
        case .svg: "doc.richtext.fill"
        case .video: "film.fill"
        case .other:
            switch otherSymbol {
            case .document: "doc.text.fill"
            case .archive: "archivebox.fill"
            case .installer: "shippingbox.fill"
            case .audio: "waveform"
            case .pdf: "doc.richtext.fill"
            case .font: "textformat"
            case .executable: "terminal.fill"
            case .binary: "doc.fill"
            }
        }
    }

    private var otherSymbol: OtherKind {
        if case let .other(kind) = self { return kind }
        return .binary
    }

    private static let rasterFormatsByExtension: [String: RasterImageFormat] = [
        "png": .png,
        "jpg": .jpeg,
        "jpeg": .jpeg,
        "gif": .gif,
        "bmp": .bmp,
        "tif": .tiff,
        "tiff": .tiff,
        "webp": .webp,
        "heic": .heic,
        "heif": .heif,
        "raw": .raw,
        "dng": .dng
    ]

    private static func rasterFormat(for ext: String) -> RasterImageFormat? {
        rasterFormatsByExtension[ext]
    }
}
