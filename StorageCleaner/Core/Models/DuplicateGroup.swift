import Foundation

/// A single file that belongs to a duplicate group. Files in a group are byte-identical
/// (same size and same SHA-256 content hash), so `bytes` is the same across the group.
struct DuplicateFile: Identifiable, Equatable, Hashable, Sendable, Codable {
    let url: URL
    let bytes: Int64
    let modifiedAt: Date?

    var id: URL { url }

    var displayName: String { url.lastPathComponent }
    var parentName: String { url.deletingLastPathComponent().lastPathComponent }
    var isVideo: Bool { DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased()) }
}

/// A set of two or more byte-identical files. Exactly one file is the recommended copy to
/// *keep* (`keepURL`); the rest are safe to remove. Reclaimable space is `(count - 1)` copies.
struct DuplicateGroup: Identifiable, Equatable, Hashable, Sendable, Codable {
    /// SHA-256 content hash shared by every file in the group; stable identity for the UI.
    let contentHash: String
    /// All copies in the group, including the one recommended to keep. Always 2+ entries.
    let files: [DuplicateFile]
    /// The copy recommended to keep (the most likely original). See `DuplicateKeepStrategy`.
    let keepURL: URL

    var id: String { contentHash }

    /// On-disk size of one copy. Identical across the group.
    var perFileBytes: Int64 { files.first?.bytes ?? 0 }

    /// Number of removable copies (everything except the kept one).
    var removableCount: Int { max(0, files.count - 1) }

    /// Space freed by removing every copy except the kept one.
    var reclaimableBytes: Int64 { perFileBytes * Int64(removableCount) }

    /// URLs of the copies that are safe to remove (everything except the kept one).
    var removableURLs: [URL] { files.map(\.url).filter { $0 != keepURL } }

    var isVideo: Bool { files.first?.isVideo ?? false }
}

/// Chooses which copy of a byte-identical duplicate group to keep. Because the files are
/// identical, "best" means the most likely *original*: a copy living in a permanent media
/// location, without copy markers in its name, and the oldest on disk.
enum DuplicateKeepStrategy {
    /// Lowercased filename fragments that mark a file as a generated copy rather than an original.
    private static let copyMarkers = [" copy", "copy ", "-copy", "_copy", " (1)", " (2)", " 1.", " 2.", "-1.", "-2."]

    /// Returns the file to keep. Highest score wins; ties break on the shortest path so the
    /// result is deterministic (important for tests and stable UI ordering).
    static func bestToKeep(from files: [DuplicateFile]) -> DuplicateFile {
        guard let first = files.first else {
            preconditionFailure("DuplicateKeepStrategy.bestToKeep requires a non-empty group")
        }

        return files.dropFirst().reduce(first) { best, candidate in
            let bestScore = score(best)
            let candidateScore = score(candidate)
            if candidateScore != bestScore {
                return candidateScore > bestScore ? candidate : best
            }
            // Deterministic tie-break: prefer the shorter, then lexicographically smaller path.
            let bestPath = best.url.path
            let candidatePath = candidate.url.path
            if candidatePath.count != bestPath.count {
                return candidatePath.count < bestPath.count ? candidate : best
            }
            return candidatePath < bestPath ? candidate : best
        }
    }

    /// Higher is more "original" and therefore more likely to be kept.
    private static func score(_ file: DuplicateFile) -> Int {
        var score = 0

        // Prefer permanent, curated media locations over transient inboxes.
        let path = file.url.path.lowercased()
        if path.contains("/pictures/") || path.contains("/movies/") {
            score += 40
        } else if path.contains("/documents/") {
            score += 20
        } else if path.contains("/downloads/") || path.contains("/desktop/") {
            score -= 20
        }

        // Penalize names that look like generated copies.
        let name = file.displayName.lowercased()
        if copyMarkers.contains(where: name.contains) {
            score -= 30
        }

        // Shallower paths are more likely to be the canonical location.
        let depth = file.url.pathComponents.count
        score -= depth

        // Older files are more likely to be the original; bucket to whole days to avoid noise.
        if let modifiedAt = file.modifiedAt {
            let days = Int(modifiedAt.timeIntervalSinceReferenceDate / 86_400)
            score -= days / 30 // small nudge toward older copies
        }

        return score
    }
}
