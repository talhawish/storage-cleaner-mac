import SwiftUI

struct CLIProgramRow: View {
    let program: CLIProgram
    let size: Int64?
    let isSelected: Bool
    let onToggle: () -> Void
    let onInfo: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Select \(program.displayName)")

            CLIProgramIconView(program: program)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(program.displayName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    StatusBadge(safety: program.safety)
                }

                Text(program.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(displayPath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            sizeLabel

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isHovering ? AppTheme.accent : Color.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Show details")
            .accessibilityLabel("Details for \(program.displayName)")
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(isHovering ? Color.accentColor.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder private var sizeLabel: some View {
        if let size {
            Text(StorageFormatting.bytes(size))
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44)
        }
    }

    private var displayPath: String {
        StoragePathFormatting.abbreviatingHome(program.url)
    }

    private var accessibilityDescription: String {
        var parts = [program.displayName, program.subtitle, program.safety.title]
        if let size {
            parts.append(StorageFormatting.bytes(size))
        }
        return parts.joined(separator: ", ")
    }
}

/// Shared helper for rendering filesystem paths with `~` for the home directory.
enum StoragePathFormatting {
    private static let homePath = UserHomeDirectory.path

    static func abbreviatingHome(_ url: URL) -> String {
        let path = url.path
        guard path.hasPrefix(homePath) else { return path }
        return "~" + path.dropFirst(homePath.count)
    }
}
