import Foundation

/// Immutable, non-empty snapshot of a file selection presented for cleanup.
///
/// Keeping the confirmation payload separate from live selection state prevents
/// an already-presented sheet from changing to "0 items" while cleanup updates
/// the underlying screen.
struct FileCleanupRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let urls: [URL]
    let totalBytes: Int64

    init?<URLs: Sequence>(
        urls: URLs,
        totalBytes: Int64,
        id: UUID = UUID()
    ) where URLs.Element == URL {
        let uniqueURLs = Set(urls).sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        guard !uniqueURLs.isEmpty else { return nil }

        self.id = id
        self.urls = uniqueURLs
        self.totalBytes = totalBytes
    }
}
