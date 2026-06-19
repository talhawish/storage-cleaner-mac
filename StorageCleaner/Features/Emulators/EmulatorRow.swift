import SwiftUI

/// A single OS image row inside an `EmulatorSectionCard`. Removable images get a checkbox; images that
/// can't be removed (bundled with Xcode or currently in use) show a lock with an explanation.
struct EmulatorRow: View {
    let image: EmulatorImage
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            leadingControl

            VStack(alignment: .leading, spacing: 2) {
                Text(image.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(image.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(image.removal.effectDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            sizeLabel
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovering && image.isRemovable ? Color.accentColor.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var leadingControl: some View {
        if image.isRemovable {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityLabel("Select \(image.title)")
        } else {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
                .frame(width: 18)
                .help("Bundled with Xcode or currently in use — can't be removed here.")
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var sizeLabel: some View {
        if image.bytes > 0 {
            Text(StorageFormatting.bytes(image.bytes))
                .font(.callout.monospacedDigit().weight(.semibold))
                .contentTransition(.numericText())
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44)
        }
    }

    private var accessibilityDescription: String {
        var parts = [image.title, image.detail]
        if image.bytes > 0 { parts.append(StorageFormatting.bytes(image.bytes)) }
        parts.append(image.isRemovable ? image.removal.effectDescription : "not removable")
        return parts.joined(separator: ", ")
    }
}
