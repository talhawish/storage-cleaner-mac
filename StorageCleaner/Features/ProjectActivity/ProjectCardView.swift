import SwiftUI

struct ProjectCardView: View {
    let project: ProjectInfo
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProjectIconView(
                        iconURL: project.iconURL,
                        technology: project.technology,
                        size: 40,
                        cornerRadius: 10
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(project.technology.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ActivityBadge(status: project.activityStatus)
                }

                Divider()

                HStack(spacing: 16) {
                    Label(project.lastModifiedRelative, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(StorageFormatting.bytes(project.totalSize))
                        .font(.callout.monospacedDigit().weight(.medium))
                }

                if project.dependencySize > 0 {
                    HStack(spacing: 6) {
                        Text("Dependencies:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(StorageFormatting.bytes(project.dependencySize))
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isHovering ? Color(hex: project.technology.color).opacity(0.4) : .clear, lineWidth: 1.5)
            }
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Opens project details")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityDescription: String {
        "\(project.name), \(project.technology.rawValue), \(project.activityStatus.label), "
            + "\(StorageFormatting.bytes(project.totalSize)), modified \(project.lastModifiedRelative)"
    }
}

struct ActivityBadge: View {
    let status: ProjectActivityStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 9))
                .accessibilityHidden(true)
            Text(status.label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: status.color).opacity(0.15), in: Capsule())
        .foregroundStyle(Color(hex: status.color))
    }
}
