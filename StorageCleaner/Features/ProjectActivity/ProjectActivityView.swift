import SwiftUI

struct ProjectActivityView: View {
    @State var viewModel = ProjectActivityViewModel()
    @State private var selectedProject: ProjectInfo?
    @State var showHibernateSheet = false
    @AppStorage("inactivityThreshold")
    private var inactivityThreshold: InactivityThreshold = .oneMonth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if viewModel.isScanning {
                    scanningView
                } else if let snapshot = viewModel.snapshot, !snapshot.projects.isEmpty {
                    dashboard(snapshot: snapshot)
                } else {
                    emptyState
                }
            }
            .padding(28)
        }
        .navigationTitle("Project Activity")
        .navigationSubtitle(subtitleText)
        .accessibilityIdentifier("project-activity-root")
        .toolbar { scanToolbarItem }
        .onChange(of: inactivityThreshold, initial: true) { _, newValue in
            viewModel.inactivityThreshold = newValue
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(
                project: project,
                onHibernate: { project in
                    await viewModel.hibernate(project)
                },
                onCompress: { project in
                    await viewModel.compress(project)
                }
            )
        }
        .sheet(isPresented: $showHibernateSheet) {
            HibernateSheet(
                projects: viewModel.inactiveProjects,
                threshold: inactivityThreshold
            ) { projects in
                await viewModel.hibernate(projects)
            }
        }
    }

    @ToolbarContentBuilder private var scanToolbarItem: some ToolbarContent {
        ToolbarItem {
            if viewModel.isScanning {
                Button(role: .cancel) {
                    viewModel.cancelScan()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    viewModel.scan()
                } label: {
                    Label("Scan Projects", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var subtitleText: String {
        if viewModel.isScanning { return "Scanning…" }
        guard let snapshot = viewModel.snapshot, !snapshot.projects.isEmpty else { return "" }
        let count = "^[\(snapshot.projects.count) project](inflect: true)"
        return "\(count) · \(StorageFormatting.bytes(snapshot.totalSize)) total"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Project Activity")
                    .font(.largeTitle.bold())
                Text("Discover inactive projects eating up disk space.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !viewModel.inactiveProjects.isEmpty {
                Button {
                    showHibernateSheet = true
                } label: {
                    Label("Hibernate Inactive", systemImage: "archivebox.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .controlSize(.large)
            VStack(spacing: 6) {
                Text("Scanning for projects…")
                    .font(.headline)
                Text("Looking for project markers across your home directory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Cancel Scan") {
                viewModel.cancelScan()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func dashboard(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            overviewCards(snapshot: snapshot)

            if !viewModel.inactiveProjects.isEmpty {
                inactiveBanner
            }

            technologyBreakdown(snapshot: snapshot)
            activityTimeline(snapshot: snapshot)

            if viewModel.hasActiveFilters {
                ActiveFilterBar(
                    technology: viewModel.selectedTechnology,
                    status: viewModel.selectedStatus,
                    onClearTechnology: { viewModel.selectedTechnology = nil },
                    onClearStatus: { viewModel.selectedStatus = nil },
                    onClearAll: viewModel.clearFilters
                )
            }

            projectGrid
        }
    }

    /// Opens the detail sheet for a project. Exposed (non-private) so the
    /// dashboard extension can trigger selection.
    func selectProject(_ project: ProjectInfo) {
        selectedProject = project
    }

    private var emptyState: some View {
        AnimatedEmptyState(
            title: "No projects found",
            message: "Scan to discover developer projects across your home directory "
                + "and spot the ones quietly eating disk space.",
            actionTitle: "Scan Projects",
            systemImage: "folder.badge.questionmark",
            action: viewModel.scan
        )
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

struct TechnologyBreakdownEntry {
    let technology: ProjectTechnology
    let count: Int
    let size: Int64
}
