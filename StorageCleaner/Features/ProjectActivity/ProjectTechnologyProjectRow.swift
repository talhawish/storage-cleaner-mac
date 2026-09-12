import SwiftUI

struct ProjectTechnologyProjectRow: View {
    let project: ProjectInfo
    let permissionHandler: (any StoragePermissionHandling)?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ProjectIconView(
                iconURL: project.iconURL,
                technology: project.technology,
                fallback: project.iconFallback,
                permissionHandler: permissionHandler,
                size: 44,
                cornerRadius: AppTheme.Radius.chip
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.small) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let primaryFramework = ProjectFramework.primary(in: project.frameworks) {
                        ProjectFrameworkMarkView(framework: primaryFramework, size: 20)

                        Text(project.frameworkSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(project.path.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(project.path.path)

                HStack(spacing: AppTheme.Spacing.medium) {
                    Label(project.lastModifiedRelative, systemImage: "clock")

                    if !project.components.isEmpty {
                        Label(
                            ProjectCountFormatting.nestedProjects(project.components.count),
                            systemImage: "square.stack.3d.up.fill"
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: AppTheme.Spacing.mediumLarge)

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.extraSmall) {
                Text(StorageFormatting.bytes(project.totalSize))
                    .font(.callout.monospacedDigit().weight(.medium))

                ActivityBadge(status: project.activityStatus)

                if project.dependencySize > 0 {
                    Label(StorageFormatting.bytes(project.dependencySize), systemImage: "shippingbox.fill")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.orange)
                        .help("Regenerable dependencies")
                }
            }
            .frame(minWidth: 112, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.Spacing.mediumLarge)
        .padding(.vertical, AppTheme.Spacing.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [
            project.name,
            project.path.path,
            project.activityStatus.label,
            "\(StorageFormatting.bytes(project.totalSize)) total"
        ]
        if !project.frameworks.isEmpty {
            parts.append(project.frameworkSummary)
        }
        if project.dependencySize > 0 {
            parts.append("\(StorageFormatting.bytes(project.dependencySize)) dependencies")
        }
        if !project.components.isEmpty {
            parts.append(ProjectCountFormatting.nestedProjects(project.components.count))
        }
        return parts.joined(separator: ", ")
    }
}
