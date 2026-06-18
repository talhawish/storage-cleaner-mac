import SwiftUI

struct ProjectDetailView: View {
    let project: ProjectInfo
    @Environment(\.dismiss) private var dismiss
    @State private var showRevealConfirmation = false
    @State private var showHibernateConfirmation = false

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
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .confirmationDialog(
                "Hibernate this project?",
                isPresented: $showHibernateConfirmation,
                titleVisibility: .visible
            ) {
                Button("Archive to ~/.hibernated/") { hibernateProject() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will compress and move the project folder to ~/.hibernated/. You can restore it later.")
            }
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: project.technology.color).opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: project.technology.symbolName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(hex: project.technology.color))
            }
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
        .background(Color(hex: project.activityStatus.color).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    Text(project.technology.rawValue)
                        .font(.subheadline.weight(.medium))
                }

                Text("Marker files: \(project.technology.markerFiles.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Label("Hibernate", systemImage: "archivebox.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(project.activityStatus == .abandoned ? .red : AppTheme.orange)
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
        let hibernateBase = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hibernated")
        try? FileManager.default.createDirectory(at: hibernateBase, withIntermediateDirectories: true)

        let archiveName = "\(project.name)_\(Int(Date().timeIntervalSince1970))"
        let archivePath = hibernateBase.appendingPathComponent("\(archiveName).tar.gz")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-czf", archivePath.path, "-C", project.path.deletingLastPathComponent().path, project.path.lastPathComponent]
        try? process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            try? FileManager.default.removeItem(at: project.path)
            dismiss()
        }
    }
}
