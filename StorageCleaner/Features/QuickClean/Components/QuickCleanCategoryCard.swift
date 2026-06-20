import SwiftUI

/// One collapsible category in the Quick Clean review list. Owns the header
/// (icon, name, safety badge, byte total, expand chevron) and the list of
/// `QuickCleanFileRow`s beneath it. The category-level "select all" checkbox
/// surfaces the partial-selection state as a dash, mirroring Finder.
struct QuickCleanCategoryCard: View {
    let category: QuickCleanCategory
    let isExpanded: Bool
    let isFullySelected: Bool
    let isPartiallySelected: Bool
    let tint: Color
    let onToggleCategory: () -> Void
    let onToggleExpansion: () -> Void
    let onToggleItem: (QuickCleanItem) -> Void
    let isItemSelected: (QuickCleanItem) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if isExpanded {
                Divider().padding(.leading, 56)
                VStack(spacing: 0) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                        QuickCleanFileRow(
                            item: item,
                            isSelected: isItemSelected(item),
                            isDisabled: false,
                            accentTint: tint,
                            onToggle: { onToggleItem(item) }
                        )
                        if index < category.items.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { isFullySelected || isPartiallySelected },
                set: { _ in onToggleCategory() }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Select all in \(category.name)")

            Button(action: onToggleExpansion) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.14))
                            .frame(width: 32, height: 32)
                        Image(systemName: category.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(category.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            StatusBadge(safety: category.safety)
                        }
                        Text(itemSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(StorageFormatting.bytes(category.bytes))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("\(StorageFormatting.items(category.itemCount)) item\(category.itemCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 96, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                        )
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.snappy(duration: 0.22), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isExpanded
                    ? "Collapse \(category.name), \(itemSummary)"
                    : "Expand \(category.name), \(itemSummary)"
            )
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var itemSummary: String {
        let count = category.itemCount
        return "\(count) item\(count == 1 ? "" : "s") · \(StorageFormatting.bytes(category.bytes))"
    }
}
