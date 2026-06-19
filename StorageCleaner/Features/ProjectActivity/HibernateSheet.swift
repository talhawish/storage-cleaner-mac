import SwiftUI

struct HibernateSheet: View {
    let projects: [ProjectInfo]
    let threshold: InactivityThreshold
    let onHibernate: ([ProjectInfo]) async -> HibernationSummary

    @Environment(\.dismiss)
    private var dismiss
    @State private var selectedProjects: Set<UUID> = []
    @State private var isHibernating = false
    @State private var summary: HibernationSummary?

    /// Space that hibernating every listed project would reclaim — the sum of
    /// their regenerable dependency sizes. Computed locally so it always
    /// reflects the projects actually shown.
    private var hibernatableSize: Int64 {
        projects.reduce(0) { $0 + $1.dependencySize }
    }

    private var totalSelectedSize: Int64 {
        projects
            .filter { selectedProjects.contains($0.id) }
            .reduce(0) { $0 + $1.dependencySize }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let summary {
                    completionView(summary: summary)
                } else {
                    projectList
                }
            }
            .navigationTitle("Hibernate Projects")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                if summary == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Hibernate Selected (\(selectedProjects.count))") {
                            performHibernate()
                        }
                        .disabled(selectedProjects.isEmpty || isHibernating)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.orange)
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader
            Divider()
            if isHibernating {
                hibernatingView
            } else {
                List(projects) { project in
                    ProjectSelectionRow(
                        project: project,
                        isSelected: selectedProjects.contains(project.id),
                        onToggle: { toggleSelection(project) }
                    )
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These projects have been inactive for over \(threshold.durationPhrase). Hibernating "
                + "moves each project's regenerable dependencies to the Trash and keeps your source "
                + "intact — rebuild them anytime with a single install.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("^[\(projects.count) project](inflect: true)", systemImage: "folder.fill")
                Label(StorageFormatting.bytes(hibernatableSize), systemImage: "internaldrive")
                if !selectedProjects.isEmpty {
                    Label(
                        "Selected: \(StorageFormatting.bytes(totalSelectedSize))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(AppTheme.orange)
                }
            }
            .font(.caption)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.orange.opacity(0.06))
    }

    private var hibernatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Reclaiming dependencies…")
                .font(.headline)
            Text("This can take a moment for large folders.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func completionView(summary: HibernationSummary) -> some View {
        VStack(spacing: 18) {
            Image(systemName: summary.failed.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(summary.failed.isEmpty ? AppTheme.mint : AppTheme.orange)
                .accessibilityHidden(true)

            Text(summary.failed.isEmpty ? "Hibernation Complete" : "Hibernation Finished With Issues")
                .font(.title.bold())

            Text("Reclaimed \(StorageFormatting.bytes(summary.reclaimedBytes)) of dependencies from "
                + "^[\(summary.succeeded.count) project](inflect: true). Your source is untouched.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !summary.failed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.failed) { outcome in
                        Label(
                            "\(outcome.project.name): \(outcome.failureReason ?? "Unknown error.")",
                            systemImage: "xmark.octagon.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("Removed dependencies are in the Trash until you empty it, "
                + "and rebuild with a single install command.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleSelection(_ project: ProjectInfo) {
        if selectedProjects.contains(project.id) {
            selectedProjects.remove(project.id)
        } else {
            selectedProjects.insert(project.id)
        }
    }

    private func performHibernate() {
        let selected = projects.filter { selectedProjects.contains($0.id) }
        guard !selected.isEmpty else { return }
        isHibernating = true
        Task {
            let result = await onHibernate(selected)
            isHibernating = false
            summary = result
        }
    }
}

struct ProjectSelectionRow: View {
    let project: ProjectInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? AppTheme.orange : Color(white: 0.55))

                ProjectIconView(iconURL: project.iconURL, technology: project.technology, size: 32, cornerRadius: 8)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("\(project.technology.rawValue) · \(project.lastModifiedRelative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(StorageFormatting.bytes(project.dependencySize))
                        .font(.callout.monospacedDigit().weight(.medium))
                        .foregroundStyle(AppTheme.orange)
                    Text("reclaimable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        "\(project.name), \(project.technology.rawValue), "
            + "\(StorageFormatting.bytes(project.dependencySize)) reclaimable"
    }
}
