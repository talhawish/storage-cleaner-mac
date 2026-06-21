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
                } else if viewModel.hasScanned {
                    emptyState
                } else {
                    initialState
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
        ScanningLoaderView(
            title: "Finding your developer projects",
            subtitle: "Detecting Xcode, Node.js, Rust, Go, Android, Python, and more across your home directory.",
            progress: nil,
            currentLocation: "~/",
            scanners: [
                ScannerLoaderItem(
                    id: "home-directory",
                    title: "Home directory",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Matching Xcode, package.json, Cargo.toml, go.mod, build.gradle…",
                    systemImage: "folder.fill",
                    tint: AppTheme.accent
                )
            ],
            cancelAction: viewModel.cancelScan
        )
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

    private var initialState: some View {
        InitialStateView(
            title: "Discover your project activity",
            subtitle: "Scans your home directory for project markers — Xcode workspaces, "
                + "Cargo.toml, go.mod, build.gradle, package.json, pubspec.yaml, .sln files, "
                + "and more — then surfaces inactive ones you can hibernate or compress.",
            highlights: [
                InitialStateHighlight(title: "Xcode, Swift", systemImage: "hammer.fill"),
                InitialStateHighlight(title: "Android, Kotlin, Java, Flutter", systemImage: "square.stack.3d.up.fill"),
                InitialStateHighlight(title: "Node, React, PHP, Ruby", systemImage: "globe"),
                InitialStateHighlight(title: "Rust, Go, Python, .NET", systemImage: "terminal.fill")
            ],
            actionTitle: "Scan Projects",
            systemImage: "clock.badge.checkmark",
            tint: AppTheme.accent,
            action: viewModel.scan
        )
        .accessibilityIdentifier("project-activity-initial")
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No active projects detected",
            message: "Scan your home directory to surface every developer project and spot the "
                + "ones quietly eating disk space.",
            systemImage: "folder.badge.questionmark",
            tint: AppTheme.accent,
            actionTitle: "Scan Projects",
            action: viewModel.scan
        )
    }
}

struct TechnologyBreakdownEntry {
    let technology: ProjectTechnology
    let count: Int
    let size: Int64
}
