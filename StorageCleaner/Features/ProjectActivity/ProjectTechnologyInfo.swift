import SwiftUI

/// Technology card showing the root identity, detection markers, and nested
/// projects discovered inside a workspace or monorepo.
struct ProjectTechnologyInfo: View {
    let project: ProjectInfo
    let permissionHandler: (any StoragePermissionHandling)?

    var body: some View {
        AppModalSection(
            title: "Technology",
            subtitle: "Detection rules used to identify this project",
            systemImage: project.iconFallback.symbolName,
            tint: Color(hex: project.iconFallback.color)
        ) {
            AppModalCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    HStack(spacing: AppTheme.Spacing.medium) {
                        ProjectIconView(
                            iconURL: project.iconURL,
                            technology: project.technology,
                            fallback: project.iconFallback,
                            permissionHandler: permissionHandler,
                            size: 36,
                            cornerRadius: AppTheme.Radius.chip
                        )
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                            Text(project.iconFallback.rawValue)
                                .font(.headline)
                            if project.iconFallback.rawValue != project.technology.rawValue {
                                Text(project.technology.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if project.childProjectCount > 0 {
                                Text("Contains \(ProjectCountFormatting.nestedProjects(project.childProjectCount))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }

                    if !project.technology.markerFiles.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                            Text("Marker files")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            Text(project.technology.markerFiles.joined(separator: ", "))
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    if !project.components.isEmpty {
                        Divider()
                        ProjectComponentListView(components: project.components)
                    }
                }
            }
        }
    }
}
