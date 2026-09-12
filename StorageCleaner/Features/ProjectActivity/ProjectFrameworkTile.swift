import SwiftUI

struct ProjectFrameworkTile: View {
    let entry: ProjectFrameworkCount

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            ProjectFrameworkMarkView(framework: entry.framework)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                Text(entry.framework.rawValue)
                    .font(.headline)
                    .lineLimit(1)
                Text(ProjectCountFormatting.projects(entry.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(entry.framework.rawValue), \(ProjectCountFormatting.projects(entry.count))"
        )
    }
}
