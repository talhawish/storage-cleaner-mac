import Foundation

/// Finds project boundaries at any depth inside a repository without emitting
/// them as separate top-level projects. Generated directories are pruned while
/// nested source projects remain discoverable at any depth.
enum ProjectComponentDiscovery {
    static func discover(
        in projectRoot: URL,
        rootTechnology: ProjectTechnology,
        fileManager: FileManager = .default
    ) -> [ProjectComponentInfo] {
        var components: [ProjectComponentInfo] = []
        guard let enumerator = fileManager.enumerator(
            at: projectRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return components }

        while !Task.isCancelled {
            let hasCandidate = autoreleasepool {
                guard let candidate = enumerator.nextObject() as? URL else { return false }
                guard (try? candidate.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    return true
                }
                if ProjectDiscoveryTraversalPolicy.shouldSkipComponent(
                    at: candidate,
                    rootTechnology: rootTechnology,
                    fileManager: fileManager
                ) {
                    enumerator.skipDescendants()
                    return true
                }

                let technologies = ProjectDetector.detectAll(at: candidate, fileManager: fileManager)
                guard let technology = ProjectDetector.primaryTechnology(in: technologies) else { return true }
                let frameworks = technologies.reduce(into: Set<ProjectFramework>()) { result, stack in
                    result.formUnion(ProjectFramework.detected(
                        at: candidate,
                        technology: stack,
                        fileManager: fileManager
                    ))
                }
                components.append(ProjectComponentInfo(
                    name: candidate.lastPathComponent,
                    path: candidate,
                    technology: technology,
                    technologies: technologies,
                    frameworks: frameworks
                ))
                enumerator.skipDescendants()
                return true
            }
            guard hasCandidate else { break }
        }

        return components.sorted { $0.path.path < $1.path.path }
    }
}
