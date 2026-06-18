import SwiftUI

struct ProjectActivityView: View {
    @State private var scanner = ProjectActivityScanner()
    @State private var snapshot: ProjectActivitySnapshot?
    @State private var isScanning = false
    @State private var selectedTechnology: ProjectTechnology?
    @State private var selectedStatus: ProjectActivityStatus?
    @State private var hibernatableSize: Int64 = 0
    @State private var selectedProject: ProjectInfo?
    @State private var showHibernateSheet = false

    private var filteredProjects: [ProjectInfo] {
        guard let snapshot else { return [] }
        var projects = snapshot.projects
        if let tech = selectedTechnology {
            projects = projects.filter { $0.technology == tech }
        }
        if let status = selectedStatus {
            projects = projects.filter { $0.activityStatus == status }
        }
        return projects
    }

    private var inactiveProjects: [ProjectInfo] {
        (snapshot?.inactiveProjects ?? []).filter { project in
            if let tech = selectedTechnology { return project.technology == tech }
            if let status = selectedStatus { return project.activityStatus == status }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if isScanning {
                    scanningView
                } else if let snapshot, !snapshot.projects.isEmpty {
                    dashboard(snapshot: snapshot)
                } else {
                    emptyState
                }
            }
            .padding(28)
        }
        .navigationTitle("Project Activity")
        .navigationSubtitle(subtitleText)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await performScan() }
                } label: {
                    Label(isScanning ? "Scanning…" : "Scan Projects", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning)
            }
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project)
        }
        .sheet(isPresented: $showHibernateSheet) {
            HibernateSheet(projects: inactiveProjects, hibernatableSize: hibernatableSize)
        }
    }

    private var subtitleText: String {
        if isScanning { return "Scanning…" }
        guard let snapshot else { return "" }
        return "\(snapshot.projects.count) projects · \(StorageFormatting.bytes(snapshot.totalSize)) total"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Project Activity")
                        .font(.largeTitle.bold())
                    Text("Discover inactive projects eating up disk space.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let snapshot, !snapshot.inactiveProjects.isEmpty {
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
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func dashboard(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            overviewCards(snapshot: snapshot)

            if !snapshot.inactiveProjects.isEmpty {
                inactiveBanner(snapshot: snapshot)
            }

            technologyBreakdown(snapshot: snapshot)

            activityTimeline(snapshot: snapshot)

            projectGrid
        }
    }

    private func overviewCards(snapshot: ProjectActivitySnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
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
                value: StorageFormatting.bytes(snapshot.hibernatableSize),
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

    private func inactiveBanner(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Inactive projects detected")
                        .font(.headline)
                    Text("You have \(snapshot.inactiveProjects.count) projects untouched for over 3 months, consuming \(StorageFormatting.bytes(snapshot.hibernatableSize)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Review & Hibernate") {
                    showHibernateSheet = true
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.orange)
            }
        }
        .padding(20)
        .background(AppTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.orange.opacity(0.2), lineWidth: 1)
        }
    }

    private func technologyBreakdown(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Space by Technology")
                .font(.headline)

            let techs = snapshot.projectsByTechnology.sorted { $0.value.reduce(0) { $0 + $1.totalSize } > $1.value.reduce(0) { $0 + $1.totalSize } }

            VStack(spacing: 10) {
                ForEach(techs, id: \.key) { technology, projects in
                    let totalSize = projects.reduce(0) { $0 + $1.totalSize }
                    let percentage = snapshot.totalSize > 0 ? Double(totalSize) / Double(snapshot.totalSize) : 0

                    TechnologyRow(
                        technology: technology,
                        size: totalSize,
                        count: projects.count,
                        percentage: percentage
                    )
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activityTimeline(snapshot: ProjectActivitySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity Overview")
                .font(.headline)

            let byStatus = snapshot.projectsByActivity

            HStack(spacing: 12) {
                ForEach(ProjectActivityStatus.allCases) { status in
                    let count = byStatus[status]?.count ?? 0
                    let size = byStatus[status]?.reduce(0) { $0 + $1.totalSize } ?? 0

                    ActivityStatusCard(
                        status: status,
                        count: count,
                        size: size,
                        isSelected: selectedStatus == status,
                        onTap: {
                            withAnimation { selectedStatus = selectedStatus == status ? nil : status }
                        }
                    )
                }
            }
        }
    }

    private var projectGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Projects")
                    .font(.headline)
                Spacer()
                Text("\(filteredProjects.count) projects")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 320, maximum: 500), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredProjects) { project in
                    ProjectCardView(project: project, onSelect: { selectedProject = project })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No projects found")
                .font(.title2.weight(.medium))
            Text("Tap \"Scan Projects\" to discover projects across your home directory.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Scan Projects") {
                Task { await performScan() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func performScan() async {
        isScanning = true
        snapshot = await scanner.scan()
        isScanning = false
    }
}

struct OverviewStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
    }
}

struct TechnologyRow: View {
    let technology: ProjectTechnology
    let size: Int64
    let count: Int
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: technology.color))
                .frame(width: 10, height: 10)

            Text(technology.rawValue)
                .font(.subheadline.weight(.medium))
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: technology.color).opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: technology.color))
                        .frame(width: geo.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(count) projects")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            Text(StorageFormatting.bytes(size))
                .font(.caption.monospacedDigit().weight(.medium))
                .frame(width: 70, alignment: .trailing)
        }
    }
}

struct ActivityStatusCard: View {
    let status: ProjectActivityStatus
    let count: Int
    let size: Int64
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: status.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: status.color))

                Text("\(count)")
                    .font(.title2.bold())

                Text(status.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(StorageFormatting.bytes(size))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color(hex: status.color).opacity(0.1) : Color(white: 0.9).opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(hex: status.color).opacity(0.4) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255,
            blue: Double(rgbValue & 0x0000FF) / 255
        )
    }
}
