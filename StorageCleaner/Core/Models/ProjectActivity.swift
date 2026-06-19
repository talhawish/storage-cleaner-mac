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

/// A single developer project discovered on disk.
struct ProjectInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    let technology: ProjectTechnology
    let lastModifiedDate: Date
    let totalSize: Int64
    let childProjectCount: Int
    let dependencySize: Int64
    /// File URL of the project's icon/logo, if one was found during the scan.
    let iconURL: URL?

    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        technology: ProjectTechnology,
        lastModifiedDate: Date,
        totalSize: Int64,
        childProjectCount: Int,
        dependencySize: Int64,
        iconURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.technology = technology
        self.lastModifiedDate = lastModifiedDate
        self.totalSize = totalSize
        self.childProjectCount = childProjectCount
        self.dependencySize = dependencySize
        self.iconURL = iconURL
    }

    /// Whole days elapsed since the newest source file was modified.
    var daysSinceLastModified: Int {
        let days = Calendar.current.dateComponents([.day], from: lastModifiedDate, to: .now).day ?? 0
        return max(0, days)
    }

    var activityStatus: ProjectActivityStatus {
        .from(daysSinceLastModified: daysSinceLastModified)
    }

    var lastModifiedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastModifiedDate, relativeTo: .now)
    }

    /// Bytes of hand-written source, i.e. total minus regenerable dependencies.
    var projectSize: Int64 {
        max(0, totalSize - dependencySize)
    }

    /// Whether this project is worth hibernating: untouched for at least the
    /// configured threshold *and* carrying regenerable dependencies to reclaim.
    func isHibernatable(olderThan threshold: InactivityThreshold) -> Bool {
        daysSinceLastModified >= threshold.days && dependencySize > 0
    }

    /// A copy of this project as it stands once its dependencies have been
    /// reclaimed: only hand-written source remains. Identity is preserved so the
    /// UI can update the project in place without a rescan.
    var withDependenciesReclaimed: ProjectInfo {
        ProjectInfo(
            id: id,
            name: name,
            path: path,
            technology: technology,
            lastModifiedDate: lastModifiedDate,
            totalSize: projectSize,
            childProjectCount: childProjectCount,
            dependencySize: 0,
            iconURL: iconURL
        )
    }
}

/// The result of one project-activity scan.
struct ProjectActivitySnapshot: Sendable {
    let projects: [ProjectInfo]
    let scannedAt: Date
    let scanDuration: TimeInterval

    var totalSize: Int64 {
        projects.reduce(0) { $0 + $1.totalSize }
    }

    var projectsByTechnology: [ProjectTechnology: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.technology }
    }

    var projectsByActivity: [ProjectActivityStatus: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.activityStatus }
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
