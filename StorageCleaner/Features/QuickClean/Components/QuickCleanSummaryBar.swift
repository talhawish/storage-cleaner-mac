import SwiftUI

/// Summary header shown at the top of the Quick Clean review phase. Aggregates
/// the per-category totals into a single line so the user sees the overall
/// scale of the cleanup at a glance, and surfaces a "X categories ready" hint
/// when more than one category has items.
struct QuickCleanSummaryBar: View {
    let selectedItemCount: Int
    let selectedBytes: Int64
    let totalCategories: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected \(StorageFormatting.items(selectedItemCount))")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(StorageFormatting.bytes(selectedBytes))
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())
                Text("to reclaim")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 110, alignment: .trailing)

            BulkSelectionMenu(
                onSelectAll: onSelectAll,
                onDeselectAll: onDeselectAll
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var subtitle: String {
        if totalCategories == 0 {
            return "Nothing selected yet"
        }
        if totalCategories == 1 {
            return "Across 1 category"
        }
        return "Across \(totalCategories) categories"
    }
}

/// Small popover menu offering "Select all" / "Deselect all" without the
/// chunky toolbar styling. A single chevron is hidden inside the label so the
/// control reads as a button at rest, with the standard menu indicator on
/// hover.
private struct BulkSelectionMenu: View {
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        Menu {
            Button("Select all items", systemImage: "checkmark.circle.fill", action: onSelectAll)
            Button("Deselect all items", systemImage: "circle", action: onDeselectAll)
        } label: {
            HStack(spacing: 4) {
                Text("All")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                AppTheme.accent.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
