import SwiftUI

struct ProjectComponentListView: View {
    let components: [ProjectComponentInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Nested Projects")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ForEach(components) { component in
                HStack(spacing: AppTheme.Spacing.medium) {
                    Image(systemName: component.technology.symbolName)
                        .font(AppTheme.Typography.bodyIcon)
                        .foregroundStyle(Color(hex: component.technology.color))
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                        Text(component.name)
                            .font(.callout.weight(.medium))
                        Text(component.path.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(component.path.path)
                    }

                    Spacer(minLength: AppTheme.Spacing.medium)

                    if let primary = ProjectFramework.primary(in: component.frameworks) {
                        ProjectFrameworkMarkView(framework: primary, size: 24)
                    }

                    Text(component.stackSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
