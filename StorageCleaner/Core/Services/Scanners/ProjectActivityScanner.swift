import Foundation

/// Walks the common developer project roots, detects the technology of each
/// project via `ProjectDetector`, and measures its size and last activity in a
/// single read-only filesystem pass. Cancellable throughout.
actor ProjectActivityScanner {
    private let searchPaths: [URL]
    private let maxDepth: Int
    private let permissionHandler: (any StoragePermissionHandling)?

    init(
        searchPaths: [URL] = DependencyPaths.Projects.searchRoots,
        maxDepth: Int = DependencyPaths.Projects.maxDepth,
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) {
        self.searchPaths = searchPaths
        self.maxDepth = maxDepth
        self.permissionHandler = permissionHandler
    }

    /// Runs the scan under the home folder security scope when a permission
    /// handler is wired. On sandboxed builds the scan returns an empty
    /// `accessDenied` snapshot when the user hasn't granted home folder access.
    func scan() async -> ProjectActivitySnapshot {
        let paths = searchPaths
        let depth = maxDepth
        guard let handler = permissionHandler else {
            return Self.run(paths: paths, maxDepth: depth)
        }
        return await handler.withHomeFolderAccess { access in
            guard access != nil else {
                return ProjectActivitySnapshot(
                    projects: [], scannedAt: .now, scanDuration: 0, accessDenied: true
                )
            }
            return Self.run(paths: paths, maxDepth: depth)
        }
    }

    // MARK: - Static non-isolated scan (callable from withHomeFolderAccess)

    private static func run(paths: [URL], maxDepth: Int) -> ProjectActivitySnapshot {
        let fileMgr = FileManager.default
        let start = Date()
        var projects: [ProjectInfo] = []
        var seen = Set<String>()

        for root in paths {
            guard !Task.isCancelled else { break }
            guard fileMgr.fileExists(atPath: root.path) else { continue }
            for project in walk(root, maxDepth: maxDepth, fileMgr: fileMgr) {
                let key = project.path.standardizedFileURL.path
                if seen.insert(key).inserted {
                    projects.append(project)
                }
            }
        }

        return ProjectActivitySnapshot(
            projects: projects.sorted { $0.totalSize > $1.totalSize },
            scannedAt: .now,
            scanDuration: Date().timeIntervalSince(start)
        )
    }

    // MARK: - Traversal

    private static func walk(_ dir: URL, maxDepth: Int, fileMgr: FileManager) -> [ProjectInfo] {
        var found: [ProjectInfo] = []
        let rootDepth = dir.pathComponents.count
        let enumerator = fileMgr.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let item = enumerator?.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            if item.pathComponents.count - rootDepth > maxDepth {
                enumerator?.skipDescendants()
                continue
            }
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if let tech = ProjectDetector.detect(at: item, fileManager: fileMgr),
               let info = build(at: item, technology: tech, fileMgr: fileMgr) {
                found.append(info)
                enumerator?.skipDescendants()
            }
        }
        return found
    }

    private static func build(at dir: URL, technology: ProjectTechnology, fileMgr: FileManager) -> ProjectInfo? {
        let metrics = measure(at: dir, technology: technology, fileMgr: fileMgr)
        guard metrics.totalSize > 0 else { return nil }
        let modDate = metrics.lastModified
            ?? (try? fileMgr.attributesOfItem(atPath: dir.path))?[.modificationDate] as? Date
            ?? .distantPast
        let nested = countSubs(at: dir, fileMgr: fileMgr)
        return ProjectInfo(
            name: dir.lastPathComponent,
            path: dir,
            technology: technology,
            lastModifiedDate: modDate,
            totalSize: metrics.totalSize,
            childProjectCount: nested,
            dependencySize: metrics.dependencySize,
            iconURL: metrics.iconURL
        )
    }

    // MARK: - Metrics

    private struct Metrics {
        var totalSize: Int64 = 0
        var dependencySize: Int64 = 0
        var lastModified: Date?
        var iconURL: URL?
        var iconScore = 0
        var iconDepth = Int.max
        var iconSize: Int64 = 0

        mutating func considerIcon(at url: URL, score: Int, depth: Int, size: Int64) {
            guard score > 0 else { return }
            let better = score > iconScore
                || (score == iconScore && depth < iconDepth)
                || (score == iconScore && depth == iconDepth && size > iconSize)
            guard better else { return }
            iconURL = url; iconScore = score; iconDepth = depth; iconSize = size
        }
    }

    private static func measure(at dir: URL, technology: ProjectTechnology, fileMgr: FileManager) -> Metrics {
        var metrics = Metrics()
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        guard let enumerator = fileMgr.enumerator(at: dir, includingPropertiesForKeys: keys) else { return metrics }

        let root = dir.pathComponents.count
        while let item = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  values.isDirectory != true else { continue }

            let size = Int64(values.fileSize ?? 0)
            let comps = item.pathComponents
            let rel = comps.dropFirst(root)

            if ProjectDependencyRules.isDependencyFile(item, for: technology, projectRoot: dir, fileManager: fileMgr) {
                metrics.totalSize += size
                metrics.dependencySize += size
            } else if !rel.contains(where: { $0.hasPrefix(".") }) {
                metrics.totalSize += size
                if let mod = values.contentModificationDate, mod > (metrics.lastModified ?? .distantPast) {
                    metrics.lastModified = mod
                }
                let parent = comps.count >= 2 ? comps[comps.count - 2] : ""
                let iconScore = ProjectIconLocator.score(fileName: item.lastPathComponent, parentDirectory: parent)
                metrics.considerIcon(at: item, score: iconScore, depth: rel.count, size: size)
            }
        }
        return metrics
    }

    private static func countSubs(at dir: URL, fileMgr: FileManager) -> Int {
        (try? fileMgr.contentsOfDirectory(atPath: dir.path))?
            .filter { !$0.hasPrefix(".") }
            .compactMap { ProjectDetector.detect(at: dir.appendingPathComponent($0), fileManager: fileMgr) }
            .count ?? 0
    }
}
