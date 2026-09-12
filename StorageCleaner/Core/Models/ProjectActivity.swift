import Foundation

/// How recently a project was worked on, derived from its newest source file.
enum ProjectActivityStatus: String, CaseIterable, Identifiable, Hashable, Sendable {
    case active
    case dormant
    case inactive
    case abandoned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: "Active"
        case .dormant: "Dormant"
        case .inactive: "Inactive"
        case .abandoned: "Abandoned"
        }
    }

    var description: String {
        switch self {
        case .active: "Worked on within the last 30 days"
        case .dormant: "No changes in 1–3 months"
        case .inactive: "No changes in 3–12 months"
        case .abandoned: "No changes in over a year"
        }
    }

    var color: String {
        switch self {
        case .active: "34C759"
        case .dormant: "FF9F0A"
        case .inactive: "FF453A"
        case .abandoned: "8E8E93"
        }
    }

    var icon: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .dormant: "moon.fill"
        case .inactive: "clock.fill"
        case .abandoned: "exclamationmark.triangle.fill"
        }
    }

    /// Classify a project from the number of days since it was last modified.
    static func from(daysSinceLastModified days: Int) -> ProjectActivityStatus {
        switch days {
        case ..<30: .active
        case ..<90: .dormant
        case ..<365: .inactive
        default: .abandoned
        }
    }
}

/// Whether a project's git working tree has pending changes.
struct GitStatus: Equatable, Hashable, Sendable {
    /// `true` when a `.git` directory exists at the project root.
    let isRepo: Bool
    /// Unstaged or staged changes that haven't been committed.
    let hasUncommittedChanges: Bool
    /// Commits on the current branch that haven't been pushed to the remote.
    let hasUnpushedCommits: Bool

    static let notARepo = GitStatus(isRepo: false, hasUncommittedChanges: false, hasUnpushedCommits: false)

    var hasPendingWork: Bool { hasUncommittedChanges || hasUnpushedCommits }
}

/// A single developer project discovered on disk.
struct ProjectInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    let technology: ProjectTechnology
    let rootTechnologies: Set<ProjectTechnology>
    /// Frameworks declared directly by the root manifest. The public
    /// `frameworks` view also includes nested workspace components.
    let directFrameworks: Set<ProjectFramework>
    let components: [ProjectComponentInfo]
    let lastModifiedDate: Date
    let totalSize: Int64
    let childProjectCount: Int
    let dependencySize: Int64
    /// File URL of the project's icon/logo, if one was found during the scan.
    let iconURL: URL?
    /// Most specific stack identity available for fallback icon rendering.
    let iconFallback: ProjectIconFallback
    /// Git working-tree status detected during the scan.
    let gitStatus: GitStatus

    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        technology: ProjectTechnology,
        technologies: Set<ProjectTechnology> = [],
        frameworks: Set<ProjectFramework> = [],
        components: [ProjectComponentInfo] = [],
        lastModifiedDate: Date,
        totalSize: Int64,
        childProjectCount: Int,
        dependencySize: Int64,
        iconURL: URL? = nil,
        iconFallback: ProjectIconFallback? = nil,
        gitStatus: GitStatus = .notARepo
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.technology = technology
        self.rootTechnologies = technologies.union([technology])
        self.directFrameworks = frameworks
        self.components = components
        self.lastModifiedDate = lastModifiedDate
        self.totalSize = totalSize
        self.childProjectCount = components.isEmpty ? childProjectCount : components.count
        self.dependencySize = dependencySize
        self.iconURL = iconURL
        let allFrameworks = components.reduce(into: frameworks) { result, component in
            result.formUnion(component.frameworks)
        }
        self.iconFallback = iconFallback
            ?? ProjectIconFallback(frameworks: allFrameworks, technology: technology)
        self.gitStatus = gitStatus
    }

    /// Whole days elapsed since the newest source file was modified.
    var daysSinceLastModified: Int {
        let days = Calendar.current.dateComponents([.day], from: lastModifiedDate, to: .now).day ?? 0
        return max(0, days)
    }

    var activityStatus: ProjectActivityStatus {
        .from(daysSinceLastModified: daysSinceLastModified)
    }

    /// All frameworks represented by the root and its nested components.
    var frameworks: Set<ProjectFramework> {
        components.reduce(into: directFrameworks) { result, component in
            result.formUnion(component.frameworks)
        }
    }

    /// Every stack whose regenerable dependencies live under this root.
    var technologies: Set<ProjectTechnology> {
        components.reduce(into: rootTechnologies) { result, component in
            result.formUnion(component.technologies)
        }
    }

    var dependencyScopes: [ProjectDependencyScope] {
        [ProjectDependencyScope(root: path, technologies: rootTechnologies)]
            + components.map {
                ProjectDependencyScope(root: $0.path, technologies: $0.technologies)
            }
    }

    /// Framework occurrence counts treat each nested project as its own
    /// project while root storage remains a single allocation.
    var frameworkProjectCounts: [ProjectFramework: Int] {
        var counts = directFrameworks.reduce(into: [ProjectFramework: Int]()) { result, framework in
            result[framework, default: 0] += 1
        }
        for component in components {
            for framework in component.frameworks {
                counts[framework, default: 0] += 1
            }
        }
        return counts
    }

    var frameworkSummary: String {
        frameworks.map(\.rawValue).sorted().joined(separator: " · ")
    }

    var lastModifiedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastModifiedDate, relativeTo: .now)
    }

    /// Project data kept during hibernation: source, repository metadata, and
    /// other files that are not known regenerable dependencies.
    var projectSize: Int64 {
        max(0, totalSize - dependencySize)
    }

    /// Whether this project is worth hibernating: untouched for at least the
    /// configured threshold *and* carrying regenerable dependencies to reclaim.
    func isHibernatable(olderThan threshold: InactivityThreshold) -> Bool {
        daysSinceLastModified >= threshold.days && dependencySize > 0
    }

    func withDependencySize(_ newDependencySize: Int64) -> ProjectInfo {
        let normalizedDependencySize = max(0, newDependencySize)
        return ProjectInfo(
            id: id,
            name: name,
            path: path,
            technology: technology,
            technologies: rootTechnologies,
            frameworks: directFrameworks,
            components: components,
            lastModifiedDate: lastModifiedDate,
            totalSize: projectSize + normalizedDependencySize,
            childProjectCount: childProjectCount,
            dependencySize: normalizedDependencySize,
            iconURL: iconURL,
            iconFallback: iconFallback,
            gitStatus: gitStatus
        )
    }
}

/// The result of one project-activity scan.
struct ProjectActivitySnapshot: Sendable {
    let projects: [ProjectInfo]
    let scannedAt: Date
    let scanDuration: TimeInterval
    /// `true` when the scan could not access the home directory because the
    /// security-scoped bookmark is missing or TCC denied access. The scanner
    /// returns an empty project list in this case so the view can show a
    /// permission prompt rather than a misleading "no projects" empty state.
    var accessDenied = false

    var totalSize: Int64 {
        projects.reduce(0) { $0 + $1.totalSize }
    }

    var projectsByTechnology: [ProjectTechnology: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.technology }
    }

    var projectsByActivity: [ProjectActivityStatus: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.activityStatus }
    }

    var projectCountsByFramework: [ProjectFramework: Int] {
        projects.reduce(into: [:]) { counts, project in
            for (framework, projectCount) in project.frameworkProjectCounts {
                counts[framework, default: 0] += projectCount
            }
        }
    }

    var frameworkBreakdown: [ProjectFrameworkCount] {
        projectCountsByFramework
            .map { ProjectFrameworkCount(framework: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.framework.rawValue < rhs.framework.rawValue
                    : lhs.count > rhs.count
            }
    }

    func technologyDetail(for technology: ProjectTechnology) -> ProjectTechnologyDetail {
        ProjectTechnologyDetail(
            technology: technology,
            projects: (projectsByTechnology[technology] ?? []).sorted { $0.totalSize > $1.totalSize }
        )
    }

    /// Projects untouched for at least the threshold that still carry
    /// regenerable dependencies — the candidates worth hibernating.
    func inactiveProjects(olderThan threshold: InactivityThreshold) -> [ProjectInfo] {
        projects.filter { $0.isHibernatable(olderThan: threshold) }
    }

    /// Space hibernation can reclaim: the dependency bytes of every candidate.
    func hibernatableSize(olderThan threshold: InactivityThreshold) -> Int64 {
        inactiveProjects(olderThan: threshold).reduce(0) { $0 + $1.dependencySize }
    }
}
