import SwiftUI

struct ProjectTechnologyMetricsView: View {
    let detail: ProjectTechnologyDetail
    let threshold: InactivityThreshold

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            OverviewStatCard(
                title: "Projects",
                value: detail.projects.count.formatted(),
                icon: "folder.fill",
                color: AppTheme.accent
            )
            OverviewStatCard(
                title: "Total Size",
                value: StorageFormatting.bytes(detail.totalSize),
                icon: "internaldrive.fill",
                color: AppTheme.cyan
            )
            OverviewStatCard(
                title: "Dependencies",
                value: StorageFormatting.bytes(detail.dependencySize),
                icon: "shippingbox.fill",
                color: AppTheme.violet
            )
            OverviewStatCard(
                title: "Hibernatable",
                value: StorageFormatting.bytes(detail.hibernatableSize(olderThan: threshold)),
                icon: "archivebox.fill",
                color: AppTheme.orange
            )
        }
    }
}
