import Foundation

/// Walks the common developer project roots, detects the technology of each
/// project via `ProjectDetector`, and measures its size and last activity in a
/// single read-only filesystem pass. Cancellable throughout.
actor ProjectActivityScanner {
    private let fileManager = FileManager.default
    private let searchPaths: [URL]
    private let maxDepth: Int

    init(
        searchPaths: [URL] = DependencyPaths.Projects.searchRoots,
        maxDepth: Int = DependencyPaths.Projects.maxDepth
    ) {
        self.searchPaths = searchPaths
        self.maxDepth = maxDepth
    }

    func scan() async -> ProjectActivitySnapshot {
        let startTime = Date()
        var projects: [ProjectInfo] = []
        var seenPaths = Set<String>()

        for searchPath in searchPaths {
            guard !Task.isCancelled else { break }
            guard fileManager.fileExists(atPath: searchPath.path) else { continue }

            for project in scanDirectory(searchPath) {
                let key = project.path.standardizedFileURL.path
                if seenPaths.insert(key).inserted {
                    projects.append(project)
                }
            }
        }

        return ProjectActivitySnapshot(
            projects: projects.sorted { $0.totalSize > $1.totalSize },
            scannedAt: .now,
            scanDuration: Date().timeIntervalSince(startTime)
        )
    }

    // MARK: - Traversal

    private func scanDirectory(_ directory: URL) -> [ProjectInfo] {
        var projects: [ProjectInfo] = []
        let rootDepth = directory.pathComponents.count
        let enumerator = fileManager.enumerator(
            at: directory,
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

            if let technology = ProjectDetector.detect(at: item, fileManager: fileManager),
               let project = buildProjectInfo(at: item, technology: technology) {
                projects.append(project)
                enumerator?.skipDescendants()
            }
        }

        return projects
    }

    private func buildProjectInfo(at directory: URL, technology: ProjectTechnology) -> ProjectInfo? {
        let metrics = measure(at: directory, technology: technology)
        guard metrics.totalSize > 0 else { return nil }

        return ProjectInfo(
            name: directory.lastPathComponent,
            path: directory,
            technology: technology,
            lastModifiedDate: metrics.lastModified ?? directoryModificationDate(directory),
            totalSize: metrics.totalSize,
            childProjectCount: countSubProjects(at: directory),
            dependencySize: metrics.dependencySize,
            iconURL: metrics.iconURL
        )
    }

    // MARK: - Metrics (single pass)

    private struct ProjectMetrics {
        var totalSize: Int64 = 0
        var dependencySize: Int64 = 0
        /// Newest modification among non-dependency files, or `nil` if none seen.
        var lastModified: Date?
        /// Best icon/logo candidate found, with the score/depth/size used to
        /// break ties (higher score, then shallower, then larger wins).
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
            iconURL = url
            iconScore = score
            iconDepth = depth
            iconSize = size
        }
    }

    /// Walk the project tree once to gather total size, dependency size, and the
    /// most recent source-file modification (dependency files are excluded so an
    /// install/build does not make the project look freshly worked on).
    private func measure(at directory: URL, technology: ProjectTechnology) -> ProjectMetrics {
        var metrics = ProjectMetrics()
        let keys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey]
        // Hidden files are *not* skipped: many dependency folders are hidden
        // (`.build`, `.gradle`, `.dart_tool`, …) and must be measured so the
        // reclaimable estimate is accurate. Hidden non-dependency files (`.git`)
        // are ignored below so neither size nor activity is skewed by them.
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys
        ) else { return metrics }

        let rootDepth = directory.pathComponents.count
        let dependencyNames = technology.dependencyDirectoryNames

        while let item = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard let values = try? item.resourceValues(forKeys: Set(keys)),
                  values.isDirectory != true else { continue }

            let size = Int64(values.fileSize ?? 0)
            let components = item.pathComponents
            let relativeComponents = components.dropFirst(rootDepth)

            if relativeComponents.contains(where: dependencyNames.contains) {
                metrics.totalSize += size
                metrics.dependencySize += size
            } else if !relativeComponents.contains(where: { $0.hasPrefix(".") }) {
                metrics.totalSize += size
                if let modified = values.contentModificationDate,
                   modified > (metrics.lastModified ?? .distantPast) {
                    metrics.lastModified = modified
                }
                let parentName = components.count >= 2 ? components[components.count - 2] : ""
                let score = ProjectIconLocator.score(fileName: item.lastPathComponent, parentDirectory: parentName)
                metrics.considerIcon(at: item, score: score, depth: relativeComponents.count, size: size)
            }
        }

        return metrics
    }

    private func countSubProjects(at directory: URL) -> Int {
        let entries = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return entries.filter { name in
            guard !name.hasPrefix(".") else { return false }
            return ProjectDetector.detect(at: directory.appendingPathComponent(name), fileManager: fileManager) != nil
        }.count
    }

    private func directoryModificationDate(_ directory: URL) -> Date {
        (try? fileManager.attributesOfItem(atPath: directory.path))?[.modificationDate] as? Date ?? .distantPast
    }
}
