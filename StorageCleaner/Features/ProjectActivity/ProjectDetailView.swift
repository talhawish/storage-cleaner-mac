import SwiftUI

struct ProjectDetailView: View {
    let project: ProjectInfo
    let onHibernate: (ProjectInfo) async -> HibernationOutcome
    @Environment(\.dismiss)
    private var dismiss
    @State private var showHibernateConfirmation = false
    @State private var isHibernating = false
    @State private var hibernationError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    projectHeader
                    activityBanner
                    sizeBreakdown
                    technologyInfo
                    locationInfo
                }
                .padding(28)
            }
            .navigationTitle(project.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .confirmationDialog(
                "Hibernate this project?",
                isPresented: $showHibernateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Move Dependencies to Trash") { hibernateProject() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This moves \(StorageFormatting.bytes(project.dependencySize)) of regenerable "
                    + "dependencies to the Trash and keeps your source. Rebuild them anytime.")
            }
            .alert("Couldn't hibernate", isPresented: hibernationErrorBinding) {
                Button("OK", role: .cancel) { hibernationError = nil }
            } message: {
                Text(hibernationError ?? "")
            }
        }
    }

    private var hibernationErrorBinding: Binding<Bool> {
        Binding(
            get: { hibernationError != nil },
            set: { if !$0 { hibernationError = nil } }
        )
    }

    private var projectHeader: some View {
        HStack(spacing: 20) {
            ProjectIconView(iconURL: project.iconURL, technology: project.technology, size: 72, cornerRadius: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.title.bold())
                Text(project.technology.rawValue)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ActivityBadge(status: project.activityStatus)
        }
    }

    private var activityBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: project.activityStatus.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: project.activityStatus.color))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.activityStatus.description)
                    .font(.subheadline.weight(.medium))
                Text("Last modified \(project.lastModifiedRelative)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(
            Color(hex: project.activityStatus.color).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: project.activityStatus.color).opacity(0.2), lineWidth: 1)
        }
    }

    private var sizeBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Size Breakdown")
                .font(.headline)

            VStack(spacing: 10) {
                SizeRow(label: "Total size", size: project.totalSize, color: AppTheme.accent)
                if project.dependencySize > 0 {
                    SizeRow(label: "Dependencies", size: project.dependencySize, color: .orange)
                    SizeRow(label: "Project code", size: project.projectSize, color: .green)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var technologyInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Technology")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: project.technology.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: project.technology.color))
                        .accessibilityHidden(true)
                    Text(project.technology.rawValue)
                        .font(.subheadline.weight(.medium))
                }

                Text("Marker files: \(project.technology.markerFiles.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if project.childProjectCount > 0 {
                    Text("Contains ^[\(project.childProjectCount) nested project](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var locationInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Location")
                .font(.headline)

            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(project.path.path)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showHibernateConfirmation = true
                } label: {
                    Label(isHibernating ? "Hibernating…" : "Hibernate", systemImage: "archivebox.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(project.activityStatus == .abandoned ? .red : AppTheme.orange)
                .disabled(isHibernating || project.dependencySize == 0)
                .help(project.dependencySize == 0
                    ? "No regenerable dependencies to reclaim."
                    : "Move regenerable dependencies to the Trash, keeping your source.")
            }
        }
    }

    private struct SizeRow: View {
        let label: String
        let size: Int64
        let color: Color

        var body: some View {
            HStack(spacing: 10) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(StorageFormatting.bytes(size))
                    .font(.callout.monospacedDigit().weight(.medium))
            }
        }
    }

    private func hibernateProject() {
        isHibernating = true
        Task {
            let outcome = await onHibernate(project)
            isHibernating = false
            if outcome.succeeded {
                dismiss()
            } else {
                hibernationError = outcome.failureReason ?? "The project could not be hibernated."
            }
        }
    }
}
