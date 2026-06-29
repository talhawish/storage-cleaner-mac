import SwiftUI

/// Dashboard sections for `ProjectActivityView`. Kept in an extension so the
/// main view stays small and each section reads as a focused builder.
extension ProjectActivityView {
    func overviewCards(snapshot: ProjectActivitySnapshot) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            OverviewStatCard(
                title: "Total Projects",
                value: "\(snapshot.projects.count)",
                icon: "folder.fill",
                color: AppTheme.accent
            )
            OverviewStatCard(
                title: "Total Size",
                value: StorageFormatting.bytes(snapshot.totalSize),
                icon: "internaldrive.fill",
                color: AppTheme.cyan
            )
            OverviewStatCard(
                title: "Hibernatable",
                value: StorageFormatting.bytes(viewModel.hibernatableSize),
                icon: "archivebox.fill",
                color: AppTheme.orange
            )
            OverviewStatCard(
                title: "Technologies",
                value: "\(snapshot.projectsByTechnology.count)",
                icon: "chevron.left.forwardslash.chevron.right",
                color: AppTheme.violet
            )
        }
    }

    var inactiveBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Inactive projects detected")
                    .font(.headline)
                Text("You have ^[\(viewModel.inactiveProjects.count) project](inflect: true) untouched for over "
                    + "\(viewModel.inactivityThreshold.durationPhrase), with "
                    + "\(StorageFormatting.bytes(viewModel.hibernatableSize)) of reclaimable dependencies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Review & Hibernate") {
                requestHibernateSheet()
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.orange)
        }
        .padding(20)
        .background(AppTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.orange.opacity(0.2), lineWidth: 1)
        }
    }

    func technologyBreakdown(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Space by Technology")
                .font(.headline)

            VStack(spacing: 6) {
                ForEach(sortedTechnologies(snapshot: snapshot), id: \.technology) { entry in
                    TechnologyRow(
                        technology: entry.technology,
                        size: entry.size,
                        count: entry.count,
                        percentage: snapshot.totalSize > 0 ? Double(entry.size) / Double(snapshot.totalSize) : 0,
                        isSelected: viewModel.selectedTechnology == entry.technology,
                        onTap: { viewModel.toggleTechnology(entry.technology) }
                    )
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func activityTimeline(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity Overview")
                .font(.headline)

            let byStatus = snapshot.projectsByActivity
            HStack(spacing: 12) {
                ForEach(ProjectActivityStatus.allCases) { status in
                    let projects = byStatus[status] ?? []
                    ActivityStatusCard(
                        status: status,
                        count: projects.count,
                        size: projects.reduce(0) { $0 + $1.totalSize },
                        isSelected: viewModel.selectedStatus == status,
                        onTap: { viewModel.toggleStatus(status) }
                    )
                }
            }
        }
    }

    var projectGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Projects")
                    .font(.headline)
                Spacer()
                Text("^[\(viewModel.filteredProjects.count) project](inflect: true)")
                    .foregroundStyle(.secondary)
            }

            if viewModel.filteredProjects.isEmpty {
                noMatchesView
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 500), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.filteredProjects) { project in
                        ProjectCardView(project: project, onSelect: { selectProject(project) })
                    }
                }
            }
        }
    }

    private var noMatchesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text("No projects match the current filters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Clear Filters", action: viewModel.clearFilters)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    func sortedTechnologies(snapshot: ProjectActivitySnapshot) -> [TechnologyBreakdownEntry] {
        snapshot.projectsByTechnology
            .map { technology, projects in
                TechnologyBreakdownEntry(
                    technology: technology,
                    count: projects.count,
                    size: projects.reduce(0) { $0 + $1.totalSize }
                )
            }
            .sorted { $0.size > $1.size }
    }
}
