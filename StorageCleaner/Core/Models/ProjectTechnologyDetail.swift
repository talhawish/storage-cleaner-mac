import Foundation

/// Snapshot-derived data for one technology drill-down. Framework counts are
/// intentionally multi-valued, while byte totals count each project once.
struct ProjectTechnologyDetail: Identifiable, Sendable {
    let technology: ProjectTechnology
    let projects: [ProjectInfo]

    var id: ProjectTechnology { technology }
    var totalSize: Int64 { projects.reduce(0) { $0 + $1.totalSize } }
    var dependencySize: Int64 { projects.reduce(0) { $0 + $1.dependencySize } }

    var frameworkBreakdown: [ProjectFrameworkCount] {
        let counts = projects.reduce(into: [ProjectFramework: Int]()) { result, project in
            for (framework, projectCount) in project.frameworkProjectCounts {
                result[framework, default: 0] += projectCount
            }
        }
        return counts
            .map { ProjectFrameworkCount(framework: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count
                    ? lhs.framework.rawValue < rhs.framework.rawValue
                    : lhs.count > rhs.count
            }
    }

    func inactiveProjects(olderThan threshold: InactivityThreshold) -> [ProjectInfo] {
        projects.filter { $0.isHibernatable(olderThan: threshold) }
    }

    func hibernatableSize(olderThan threshold: InactivityThreshold) -> Int64 {
        inactiveProjects(olderThan: threshold).reduce(0) { $0 + $1.dependencySize }
    }

    var activitySummary: String {
        ProjectActivityStatus.allCases.compactMap { status in
            let count = projects.count(where: { $0.activityStatus == status })
            return count > 0 ? "\(count.formatted()) \(status.label)" : nil
        }
        .joined(separator: "  ·  ")
    }
}
