import SwiftUI

/// One file or directory in the Quick Clean review list. The row owns its
/// checkbox and the parent owns the actual selection state.
struct QuickCleanFileRow: View {
    let item: QuickCleanItem
    let isSelected: Bool
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

            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(FileRowIconStyle.background(for: item.url))
                    .frame(width: 24, height: 24)
                Image(systemName: FileRowIconStyle.symbol(for: item.url))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FileRowIconStyle.foreground(for: item.url))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(item.url.standardizedFileURL.path)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(item.displayName), \(StorageFormatting.bytes(item.bytes))"
        )
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
