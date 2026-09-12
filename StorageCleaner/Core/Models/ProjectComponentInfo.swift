import Foundation

/// A project boundary discovered inside a larger repository or workspace.
/// Components contribute stack metadata and cleanup rules, but their bytes are
/// owned by the root project so storage totals are never counted twice.
struct ProjectComponentInfo: Identifiable, Hashable, Sendable {
    let name: String
    let path: URL
    let technology: ProjectTechnology
    let technologies: Set<ProjectTechnology>
    let frameworks: Set<ProjectFramework>

    var id: String { path.standardizedFileURL.path }

    var stackSummary: String {
        let frameworkNames = frameworks.map(\.rawValue).sorted()
        if !frameworkNames.isEmpty {
            return frameworkNames.joined(separator: " · ")
        }
        return technologies.map(\.rawValue).sorted().joined(separator: " · ")
    }

    init(
        name: String,
        path: URL,
        technology: ProjectTechnology,
        technologies: Set<ProjectTechnology> = [],
        frameworks: Set<ProjectFramework>
    ) {
        self.name = name
        self.path = path
        self.technology = technology
        self.technologies = technologies.union([technology])
        self.frameworks = frameworks
    }
}
