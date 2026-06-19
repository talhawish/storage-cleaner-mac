import Foundation

struct DetailDirectoryLevel: Identifiable, Equatable, Sendable {
    let root: URL
    let title: String
    let urls: [URL]

    var id: URL { root }
}

enum DetailDirectoryChildren {
    static func level(for url: URL) -> DetailDirectoryLevel? {
        let childRoot = childrenRoot(for: url)
        let children = childURLs(in: childRoot)
        guard !children.isEmpty else { return nil }
        return DetailDirectoryLevel(root: url, title: url.lastPathComponent, urls: children)
    }

    private static func childrenRoot(for url: URL) -> URL {
        let path = url.standardizedFileURL.path
        if path == DependencyPaths.Apple.coreSimulator.standardizedFileURL.path {
            return url.appendingPathComponent("Devices", isDirectory: true)
        }
        return url
    }

    private static func childURLs(in url: URL) -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .filter { entry in
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
                return values?.isDirectory == true || values?.isRegularFile == true
            }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }
}
