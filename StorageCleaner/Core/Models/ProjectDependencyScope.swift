import Foundation

/// Technology rules attached to one exact project boundary. The nearest scope
/// owns a directory, preventing one monorepo component's generic names (such
/// as `vendor`, `build`, or `dist`) from affecting a sibling component.
struct ProjectDependencyScope: Hashable, Sendable {
    let root: URL
    let technologies: Set<ProjectTechnology>

    func contains(_ url: URL) -> Bool {
        root.matchesFilesystemURL(url) || root.isAncestor(of: url)
    }

    static func nearest(
        containing url: URL,
        in scopes: [ProjectDependencyScope]
    ) -> ProjectDependencyScope? {
        var nearestScope: ProjectDependencyScope?
        var nearestDepth = -1
        for scope in scopes {
            let depth = scope.root.pathComponents.count
            guard depth > nearestDepth, scope.contains(url) else { continue }
            nearestScope = scope
            nearestDepth = depth
        }
        return nearestScope
    }
}
