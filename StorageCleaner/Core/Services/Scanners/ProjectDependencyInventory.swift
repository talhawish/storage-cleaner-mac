import Foundation

/// Shared dependency discovery and allocated-size measurement for project
/// scanning, hibernation, and compression. Keeping these operations here makes
/// the estimate shown before an action match the directories the action uses.
enum ProjectDependencyInventory {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

    static func directories(
        in projectRoot: URL,
        technology: ProjectTechnology,
        fileManager: FileManager = .default
    ) -> [URL] {
        directories(
            in: projectRoot,
            scopes: [ProjectDependencyScope(root: projectRoot, technologies: [technology])],
            fileManager: fileManager
        )
    }

    static func directories(
        for project: ProjectInfo,
        fileManager: FileManager = .default
    ) -> [URL] {
        directories(in: project.path, scopes: project.dependencyScopes, fileManager: fileManager)
    }

    static func directories(
        in projectRoot: URL,
        scopes: [ProjectDependencyScope],
        fileManager: FileManager = .default
    ) -> [URL] {
        guard scopes.contains(where: { scope in
            scope.technologies.contains(where: { !$0.dependencyDirectoryNames.isEmpty })
        }),
              let enumerator = fileManager.enumerator(
                at: projectRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
              ) else {
            return []
        }

        var matches: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if let scope = ProjectDependencyScope.nearest(containing: url, in: scopes),
               ProjectDependencyRules.isDependencyDirectory(
                url,
                for: scope.technologies,
                projectRoot: scope.root,
                fileManager: fileManager
               ) {
                matches.append(url)
                enumerator.skipDescendants()
            }
        }
        return matches
    }

    /// Allocated bytes that would become reclaimable after removing `url`.
    /// Logical length is used only when the filesystem does not expose an
    /// allocation count.
    static func allocatedSize(
        of url: URL,
        fileManager: FileManager = .default
    ) -> Int64 {
        FileSystemItemSizer.allocatedSize(of: url, fileManager: fileManager)
    }

    static func allocatedSize(from values: URLResourceValues?) -> Int64 {
        FileSystemItemSizer.allocatedSize(from: values)
    }
}
