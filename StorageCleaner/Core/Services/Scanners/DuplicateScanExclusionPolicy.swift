import Foundation

/// Filters duplicate candidates that are likely to be source-controlled project assets,
/// generated build output, dependency payloads, or app bundles. Generic duplicate cleanup should
/// focus on loose user files; developer/project cleanup is handled by dedicated scanners.
struct DuplicateScanExclusionPolicy: Sendable {
    private static let protectedPathExtensions: Set<String> = [
        "app", "appex", "bundle", "framework", "plugin",
        "xcassets", "appiconset", "imageset", "launchimage", "iconset"
    ]

    private static let protectedComponents: Set<String> = [
        ".build", ".dart_tool", ".git", ".gradle", ".hg", ".swiftpm", ".svn",
        "DerivedData", "Pods", "__pycache__", "node_modules", "target", "vendor"
    ]

    private let projectRootPaths: [String]

    init(projectRoots: [URL]) {
        projectRootPaths = projectRoots
            .map { $0.standardizedFileURL.path }
            .sorted { $0.count > $1.count }
    }

    static func detectingProjects(under roots: [URL]) -> DuplicateScanExclusionPolicy {
        DuplicateScanExclusionPolicy(projectRoots: DuplicateProjectRootDetector().detect(in: roots))
    }

    func shouldExclude(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL

        if isUnderDetectedProject(standardizedURL) {
            return true
        }

        return standardizedURL.pathComponents.contains(where: { component in
            Self.protectedComponents.contains(component)
                || Self.protectedPathExtensions.contains((component as NSString).pathExtension.lowercased())
        })
    }

    private func isUnderDetectedProject(_ url: URL) -> Bool {
        let path = url.path
        return projectRootPaths.contains { rootPath in
            path == rootPath || path.hasPrefix(rootPath + "/")
        }
    }
}

/// Internal (not private) so `DirectorySnapshotCache` can memoize one
/// detection walk per root per scan for all duplicate scanners.
struct DuplicateProjectRootDetector {
    private let fileManager = FileManager.default
    private let maxDepth: Int

    init(maxDepth: Int = DependencyPaths.Projects.maxDepth) {
        self.maxDepth = maxDepth
    }

    func detect(in roots: [URL]) -> [URL] {
        var projectRoots: [URL] = []
        var seen = Set<String>()

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else { break }
            detectProjects(under: root, into: &projectRoots, seen: &seen)
        }

        return projectRoots
    }

    private func detectProjects(under root: URL, into projectRoots: inout [URL], seen: inout Set<String>) {
        if ProjectDetector.detect(at: root, fileManager: fileManager) != nil {
            insert(root, into: &projectRoots, seen: &seen)
            return
        }

        let rootDepth = root.pathComponents.count
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let item = enumerator?.nextObject() as? URL {
            guard !Task.isCancelled else { break }

            let depth = item.pathComponents.count - rootDepth
            if depth > maxDepth {
                enumerator?.skipDescendants()
                continue
            }

            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }

            if ProjectDetector.detect(at: item, fileManager: fileManager) != nil {
                insert(item, into: &projectRoots, seen: &seen)
                enumerator?.skipDescendants()
            }
        }
    }

    private func insert(_ url: URL, into projectRoots: inout [URL], seen: inout Set<String>) {
        let path = url.standardizedFileURL.path
        if seen.insert(path).inserted {
            projectRoots.append(url)
        }
    }
}
