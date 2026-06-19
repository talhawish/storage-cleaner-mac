import SwiftUI

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// A tappable row in the "Space by Technology" breakdown. Tapping filters the
/// project list to that technology.
struct TechnologyRow: View {
    let technology: ProjectTechnology
    let size: Int64
    let count: Int
    let percentage: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                Text("^[\(count) project](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)

                Text(StorageFormatting.bytes(size))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .frame(width: 70, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                isSelected ? Color(hex: technology.color).opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        "\(technology.rawValue), ^[\(count) project](inflect: true), " + StorageFormatting.bytes(size)
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
            .background(
                isSelected ? Color(hex: status.color).opacity(0.1) : Color(white: 0.9).opacity(0.3),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color(hex: status.color).opacity(0.4) : .clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(status.label), ^[\(count) project](inflect: true), \(StorageFormatting.bytes(size))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Shows the active technology / activity filters as removable chips, with a
/// single "Clear" action. Hidden entirely when no filter is applied.
struct ActiveFilterBar: View {
    let technology: ProjectTechnology?
    let status: ProjectActivityStatus?
    let onClearTechnology: () -> Void
    let onClearStatus: () -> Void
    let onClearAll: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Filters")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let technology {
                FilterChip(
                    label: technology.rawValue,
                    color: Color(hex: technology.color),
                    onRemove: onClearTechnology
                )
            }
            if let status {
                FilterChip(
                    label: status.label,
                    color: Color(hex: status.color),
                    onRemove: onClearStatus
                )
            }

            Spacer()

            Button("Clear All", action: onClearAll)
                .font(.caption.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption.weight(.medium))
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(label) filter")
    }
}
