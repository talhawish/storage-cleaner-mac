import SwiftUI

struct HibernateSheet: View {
    let projects: [ProjectInfo]
    let hibernatableSize: Int64
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProjects: Set<UUID> = []
    @State private var isHibernating = false
    @State private var hibernatedCount = 0
    @State private var hibernationComplete = false

    private var totalSelectedSize: Int64 {
        projects.filter { selectedProjects.contains($0.id) }.reduce(0) { $0 + $1.totalSize }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if hibernationComplete {
                    completionView
                } else {
                    projectList
                }
            }
            .navigationTitle("Hibernate Projects")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                if !hibernationComplete {
                    ToolbarItem(placement: .automatic) {
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
    }

    private var projectList: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryHeader
            Divider()
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

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("These projects have been inactive for over 3 months.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("\(projects.count) projects", systemImage: "folder.fill")
                Label(StorageFormatting.bytes(hibernatableSize), systemImage: "internaldrive")
                if selectedProjects.count > 0 {
                    Label("Selected: \(StorageFormatting.bytes(totalSelectedSize))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.orange)
                }
            }
            .font(.caption)
        }
        .padding(16)
        .background(AppTheme.orange.opacity(0.06))
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Hibernation Complete")
                .font(.title.bold())

            Text("\(hibernatedCount) projects archived to ~/.hibernated/")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("You can restore them anytime from the Hibernated folder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
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
        isHibernating = true
        let hibernateBase = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hibernated")
        try? FileManager.default.createDirectory(at: hibernateBase, withIntermediateDirectories: true)

        let selected = projects.filter { selectedProjects.contains($0.id) }
        var count = 0

        for project in selected {
            let archiveName = "\(project.name)_\(Int(Date().timeIntervalSince1970))"
            let archivePath = hibernateBase.appendingPathComponent("\(archiveName).tar.gz")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-czf", archivePath.path, "-C", project.path.deletingLastPathComponent().path, project.path.lastPathComponent]
            try? process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                try? FileManager.default.removeItem(at: project.path)
                count += 1
            }
        }

        hibernatedCount = count
        isHibernating = false
        hibernationComplete = true
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

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: project.technology.color).opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: project.technology.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: project.technology.color))
                }
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

                Text(StorageFormatting.bytes(project.totalSize))
                    .font(.callout.monospacedDigit().weight(.medium))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
