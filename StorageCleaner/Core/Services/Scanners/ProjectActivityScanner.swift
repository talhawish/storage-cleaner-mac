import Foundation

/// Walks the common developer project roots, detects the technology of each
/// project via `ProjectDetector`, and measures its size and last activity in a
/// single read-only filesystem pass. Cancellable throughout.
actor ProjectActivityScanner {
    private let searchPaths: [URL]
    private let maxDepth: Int
    private let minimumProjectSize: Int64
    private let permissionHandler: (any StoragePermissionHandling)?

    init(
        searchPaths: [URL] = DependencyPaths.Projects.searchRoots,
        maxDepth: Int = DependencyPaths.Projects.maxDepth,
        minimumProjectSize: Int64 = DependencyPaths.Projects.minimumProjectSize,
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) {
        self.searchPaths = searchPaths
        self.maxDepth = maxDepth
        self.minimumProjectSize = minimumProjectSize
        self.permissionHandler = permissionHandler
    }

    /// Runs the scan under the home folder security scope when a permission
    /// handler is wired. On sandboxed builds the scan returns an empty
    /// `accessDenied` snapshot when the user hasn't granted home folder access.
    func scan() async -> ProjectActivitySnapshot {
        let paths = searchPaths
        let depth = maxDepth
        let minimumSize = minimumProjectSize
        guard let handler = permissionHandler else {
            return Self.run(paths: paths, maxDepth: depth, minimumProjectSize: minimumSize)
        }
        return await handler.withHomeFolderAccess { access in
            guard access != nil else {
                return ProjectActivitySnapshot(
                    projects: [], scannedAt: .now, scanDuration: 0, accessDenied: true
                )
            }
            return Self.run(paths: paths, maxDepth: depth, minimumProjectSize: minimumSize)
        }
    }

    // MARK: - Static non-isolated scan (callable from withHomeFolderAccess)

    private static func run(paths: [URL], maxDepth: Int, minimumProjectSize: Int64) -> ProjectActivitySnapshot {
        let fileMgr = FileManager.default
        let start = Date.now
        var projects: [ProjectInfo] = []
        var seen = Set<String>()

        let existingRoots = paths.filter { fileMgr.fileExists(atPath: $0.path) }
        for root in nonOverlappingSearchRoots(existingRoots) {
            guard !Task.isCancelled else { break }
            for project in walk(
                root,
                maxDepth: maxDepth,
                minimumProjectSize: minimumProjectSize,
                fileMgr: fileMgr
            ) {
                let key = project.path.standardizedFileURL.path
                if seen.insert(key).inserted {
                    projects.append(project)
                }
            }
        }

        return ProjectActivitySnapshot(
            projects: projects.sorted { $0.totalSize > $1.totalSize },
            scannedAt: .now,
            scanDuration: Date.now.timeIntervalSince(start)
        )
    }

    /// Removes duplicates and descendants of roots already being scanned. The
    /// default roots include `Documents` and `Documents/GitHub`; scanning both
    /// would repeat all filesystem work under the latter.
    static func nonOverlappingSearchRoots(_ paths: [URL]) -> [URL] {
        var seen = Set<String>()
        let uniquePaths = paths.compactMap { path -> URL? in
            let standardized = path.standardizedFileURL
            return seen.insert(standardized.path).inserted ? standardized : nil
        }
        let unique = uniquePaths.sorted { lhs, rhs in
                lhs.pathComponents.count == rhs.pathComponents.count
                    ? lhs.path < rhs.path
                    : lhs.pathComponents.count < rhs.pathComponents.count
            }

        return unique.reduce(into: []) { roots, candidate in
            let candidateComponents = candidate.pathComponents
            guard !roots.contains(where: { candidateComponents.starts(with: $0.pathComponents) }) else { return }
            roots.append(candidate)
        }
    }

    // MARK: - Traversal

    private static func walk(
        _ dir: URL,
        maxDepth: Int,
        minimumProjectSize: Int64,
        fileMgr: FileManager
    ) -> [ProjectInfo] {
        var found: [ProjectInfo] = []
        let rootDepth = dir.pathComponents.count
        let enumerator = fileMgr.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while !Task.isCancelled {
            let hasItem = autoreleasepool {
                guard let item = enumerator?.nextObject() as? URL else { return false }
                if item.pathComponents.count - rootDepth > maxDepth {
                    enumerator?.skipDescendants()
                    return true
                }
                guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    return true
                }
                if ProjectActivityDiscoveryExclusions.shouldSkipProjectDiscovery(at: item, fileManager: fileMgr) {
                    enumerator?.skipDescendants()
                    return true
                }
                if let tech = ProjectDetector.detect(at: item, fileManager: fileMgr),
                   let info = build(
                    at: item,
                    technology: tech,
                    minimumProjectSize: minimumProjectSize,
                    fileMgr: fileMgr
                   ) {
                    found.append(info)
                    enumerator?.skipDescendants()
                }
                return true
            }
            guard hasItem else { break }
        }
        return found
    }

    private static func build(
        at dir: URL,
        technology: ProjectTechnology,
        minimumProjectSize: Int64,
        fileMgr: FileManager
    ) -> ProjectInfo? {
        let components = ProjectComponentDiscovery.discover(
            in: dir,
            rootTechnology: technology,
            fileManager: fileMgr
        )
        let detectedRootTechnologies = ProjectDetector.detectAll(at: dir, fileManager: fileMgr)
        let rootTechnologies = detectedRootTechnologies.isEmpty ? [technology] : detectedRootTechnologies
        let dependencyScopes = [ProjectDependencyScope(root: dir, technologies: rootTechnologies)]
            + components.map { ProjectDependencyScope(root: $0.path, technologies: $0.technologies) }
        let metrics = measure(at: dir, dependencyScopes: dependencyScopes, fileMgr: fileMgr)
        guard metrics.totalSize >= minimumProjectSize else { return nil }
        let modDate = metrics.lastModified
            ?? (try? fileMgr.attributesOfItem(atPath: dir.path))?[.modificationDate] as? Date
            ?? .distantPast
        let gitStatus = GitStatusDetector.detect(at: dir, fileManager: fileMgr)
        let directFrameworks = rootTechnologies.reduce(into: Set<ProjectFramework>()) { result, stack in
            result.formUnion(ProjectFramework.detected(at: dir, technology: stack, fileManager: fileMgr))
        }
        let allFrameworks = components.reduce(into: directFrameworks) { result, component in
            result.formUnion(component.frameworks)
        }
        return ProjectInfo(
            name: dir.lastPathComponent,
            path: dir,
            technology: technology,
            technologies: rootTechnologies,
            frameworks: directFrameworks,
            components: components,
            lastModifiedDate: modDate,
            totalSize: metrics.totalSize,
            childProjectCount: components.count,
            dependencySize: metrics.dependencySize,
            iconURL: metrics.iconURL,
            iconFallback: ProjectIconFallback(frameworks: allFrameworks, technology: technology),
            gitStatus: gitStatus
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

    private struct MetricsContext {
        let rootDepth: Int
        let dependencyScopes: [ProjectDependencyScope]
        let enumerator: FileManager.DirectoryEnumerator
        let fileManager: FileManager
    }

    private static func measure(
        at dir: URL,
        dependencyScopes: [ProjectDependencyScope],
        fileMgr: FileManager
    ) -> Metrics {
        var metrics = Metrics()
        let keys: Set<URLResourceKey> = [
            .fileAllocatedSizeKey,
            .fileSizeKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .contentModificationDateKey
        ]
        guard let enumerator = fileMgr.enumerator(
            at: dir,
            includingPropertiesForKeys: Array(keys)
        ) else { return metrics }

        let root = dir.pathComponents.count
        let context = MetricsContext(
            rootDepth: root,
            dependencyScopes: dependencyScopes,
            enumerator: enumerator,
            fileManager: fileMgr
        )
        for candidate in ProjectIconLocator.commonIconCandidates(in: dir, fileManager: fileMgr) {
            considerIconCandidate(candidate, rootDepth: root, metrics: &metrics, fileMgr: fileMgr)
        }

        while !Task.isCancelled {
            let hasItem = autoreleasepool {
                guard let item = enumerator.nextObject() as? URL else { return false }
                guard let values = try? item.resourceValues(forKeys: keys) else { return true }
                accumulateMetrics(
                    for: item,
                    values: values,
                    metrics: &metrics,
                    context: context
                )
                return true
            }
            guard hasItem else { break }
        }
        return metrics
    }

    private static func accumulateMetrics(
        for item: URL,
        values: URLResourceValues,
        metrics: inout Metrics,
        context: MetricsContext
    ) {
        if values.isDirectory == true {
            guard let scope = ProjectDependencyScope.nearest(containing: item, in: context.dependencyScopes),
                  ProjectDependencyRules.isDependencyDirectory(
                    item,
                    for: scope.technologies,
                    projectRoot: scope.root,
                    fileManager: context.fileManager
                  ) else { return }
            let size = ProjectDependencyInventory.allocatedSize(of: item, fileManager: context.fileManager)
            metrics.totalSize += size
            metrics.dependencySize += size
            context.enumerator.skipDescendants()
            return
        }

        guard values.isRegularFile == true else { return }
        let size = ProjectDependencyInventory.allocatedSize(from: values)
        let components = item.pathComponents
        let relativeComponents = components.dropFirst(context.rootDepth)
        metrics.totalSize += size
        guard !relativeComponents.contains(where: { $0.hasPrefix(".") }) else { return }

        if let modifiedAt = values.contentModificationDate,
           modifiedAt > (metrics.lastModified ?? .distantPast) {
            metrics.lastModified = modifiedAt
        }
        considerIconCandidate(
            item,
            rootDepth: context.rootDepth,
            metrics: &metrics,
            fileMgr: context.fileManager
        )
    }

    private static func considerIconCandidate(
        _ item: URL,
        rootDepth: Int,
        metrics: inout Metrics,
        fileMgr: FileManager
    ) {
        let comps = item.pathComponents
        let parent = comps.count >= 2 ? comps[comps.count - 2] : ""
        let iconScore = ProjectIconLocator.score(fileName: item.lastPathComponent, parentDirectory: parent)
        guard iconScore > 0 else { return }

        let size = ProjectDependencyInventory.allocatedSize(of: item, fileManager: fileMgr)
        metrics.considerIcon(at: item, score: iconScore, depth: max(0, comps.count - rootDepth), size: size)
    }

}

private enum ProjectActivityDiscoveryExclusions {
    static func shouldSkipProjectDiscovery(at directory: URL, fileManager: FileManager) -> Bool {
        isFlutterSDKCheckout(directory, fileManager: fileManager)
    }

    private static func isFlutterSDKCheckout(_ directory: URL, fileManager: FileManager) -> Bool {
        let binFlutter = directory.appending(path: "bin/flutter")
        let frameworkLibrary = directory.appending(path: "packages/flutter/lib", directoryHint: .isDirectory)
        let engine = directory.appending(path: "engine", directoryHint: .isDirectory)
        let dev = directory.appending(path: "dev", directoryHint: .isDirectory)

        return fileManager.fileExists(atPath: binFlutter.path)
            && fileManager.fileExists(atPath: frameworkLibrary.path)
            && (fileManager.fileExists(atPath: engine.path) || fileManager.fileExists(atPath: dev.path))
    }
}
