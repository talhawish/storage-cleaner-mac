import Foundation

extension URL {
    var normalizedFilesystemPath: String {
        let path = standardizedFileURL.path
        guard path != "/" else { return path }
        return path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    func matchesFilesystemURL(_ other: URL) -> Bool {
        normalizedFilesystemPath == other.normalizedFilesystemPath
    }

    /// True when this URL is an ancestor of `descendant` on the filesystem.
    /// Distinguishes genuine parent paths from coincidental string prefixes
    /// (e.g. "Chrome" must not claim "ChromeX") by requiring a `/`
    /// separator between the two path components.
    func isAncestor(of descendant: URL) -> Bool {
        let ancestorPath = normalizedFilesystemPath
        let descendantPath = descendant.normalizedFilesystemPath
        guard descendantPath.hasPrefix(ancestorPath) else { return false }
        let remainder = descendantPath.dropFirst(ancestorPath.count)
        return remainder.first == "/"
    }
}
