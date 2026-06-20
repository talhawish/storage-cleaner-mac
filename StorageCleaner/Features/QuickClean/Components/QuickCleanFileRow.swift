import SwiftUI

/// One file or directory in the Quick Clean review list. The row owns its
/// checkbox and the parent owns the actual selection state.
struct QuickCleanFileRow: View {
    let item: QuickCleanItem
    let isSelected: Bool
    let isDisabled: Bool
    let accentTint: Color
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .disabled(isDisabled)

            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accentTint.opacity(isDisabled ? 0.4 : 1))
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .lineLimit(1)
                Text(item.parentPath)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.url.standardizedFileURL.path)
            }

            Spacer(minLength: 8)

            Text(StorageFormatting.bytes(item.bytes))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.displayName), \(StorageFormatting.bytes(item.bytes))"
                + (isDisabled ? ", disabled" : "")
        )
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
