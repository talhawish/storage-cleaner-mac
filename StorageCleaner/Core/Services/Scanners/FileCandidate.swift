import Foundation

struct FileCandidate: Equatable, Sendable {
    let url: URL
    let bytes: Int64
}

/// A regular file observed during traversal, carrying the metadata the
/// enumeration already fetched so matchers never re-stat the file. This is
/// what makes one shared directory walk reusable by every pattern scanner.
struct FileRecord: Equatable, Sendable {
    let url: URL
    /// Allocated size captured from the enumeration's prefetched resource values.
    let bytes: Int64
    let pathExtensionLowercased: String
    let nameLowercased: String

    init(url: URL, bytes: Int64) {
        self.url = url
        self.bytes = bytes
        pathExtensionLowercased = url.pathExtension.lowercased()
        nameLowercased = url.lastPathComponent.lowercased()
    }
}

extension [FileCandidate] {
    /// Inserts `candidate` while keeping at most `limit` of the largest
    /// candidates by byte size. Shared by every traversal implementation so
    /// `prioritizeLargest` behaves identically with or without the snapshot cache.
    mutating func retainLargest(_ candidate: FileCandidate, limit: Int) {
        guard count >= limit else {
            append(candidate)
            return
        }

        guard let smallestIndex = indices.min(by: { self[$0].bytes < self[$1].bytes }),
              self[smallestIndex].bytes < candidate.bytes else {
            return
        }

        self[smallestIndex] = candidate
    }
}

struct FileCollectionResult: Equatable, Sendable {
    let candidates: [FileCandidate]
    let inspectedItemCount: Int
}

extension FileCandidate {
    var displayName: String {
        url.lastPathComponent
    }
}
