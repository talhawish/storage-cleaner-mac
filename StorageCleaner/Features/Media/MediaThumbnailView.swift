import AppKit
import SwiftUI

/// Renders a square thumbnail for a media file. The view owns its own
/// `MediaThumbnailLoadingState` and asks `MediaThumbnailProvider` for the bitmap
/// on first appearance, falling back to a typographic system icon when the file
/// can't be decoded.
struct MediaThumbnailView: View {
    let url: URL
    let sideLength: CGFloat
    let displaySideLength: CGFloat?
    let cornerRadius: CGFloat
    let contentMode: ContentMode

    @State private var state: ThumbnailState = .loading
    @State private var fileType: MediaFileType

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
        _fileType = State(initialValue: MediaFileType.classify(url: url))
    }

    /// When `displaySideLength` is set the view is a fixed square (list rows).
    /// When nil it fills its container so a parent can enforce a square crop (grid).
    private var fillsContainer: Bool { displaySideLength == nil }

    var body: some View {
        Group {
            switch state {
            case let .loaded(image):
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .accessibilityHidden(true)
            case .loading, .failed:
                placeholder
            }
        }
        .frame(width: displaySideLength, height: displaySideLength)
        .frame(
            maxWidth: fillsContainer ? .infinity : nil,
            maxHeight: fillsContainer ? .infinity : nil
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: thumbnailCacheKey) { await load() }
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary.opacity(0.45))
            .overlay {
                if case .loading = state {
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

    private var fallbackSystemImage: String {
        fileType.symbolName
    }

    private var thumbnailCacheKey: String {
        "\(url.path)|\(Int(sideLength))"
    }

    private func load() async {
        state = .loading
        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: sideLength)
        if let image {
            state = .loaded(image)
        } else {
            state = .failed
        }
    }
}

private enum ThumbnailState: Equatable {
    case loading
    case loaded(NSImage)
    case failed

    static func == (lhs: ThumbnailState, rhs: ThumbnailState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading): return true
        case (.failed, .failed): return true
        case let (.loaded(lhsImage), .loaded(rhsImage)): return lhsImage === rhsImage
        default: return false
        }
    }
}
