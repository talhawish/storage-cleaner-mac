import SwiftUI

/// "Top Cleaned Categories" card on the Cleanup History page. Aggregates bytes and items per
/// `StorageFindingKind` across every persisted cleanup and renders the top `N` rows with a share
/// bar. Surfaces the kinds the user actually cleans the most — useful as a quick "where am I
/// saving the most" answer.
struct TopCleanedCategoriesCard: View {
    let categories: [TopCleanedCategory]

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium),
        GridItem(.flexible(), spacing: AppTheme.Spacing.medium)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            SectionHeader(
                title: "Top Cleaned Categories",
                subtitle: "Where your reclaimed space has come from",
                systemImage: "chart.bar.xaxis"
            )

            LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.small) {
                ForEach(categories) { category in
                    TopCleanedCategoryRow(category: category)
                }
            }
        }
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityIdentifier("cleanup-history-top-categories")
    }
}

/// One row in the top-cleaned-categories grid: tinted icon, category title, item count, share
/// bar, and the byte total. Renders compactly so two columns fit comfortably inside the card.
private struct TopCleanedCategoryRow: View {
    let category: TopCleanedCategory

    private var tint: Color { AppTheme.color(for: category.domain) }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: category.domain.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(category.kind.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                ShareBar(fraction: category.share, tint: tint)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(StorageFormatting.bytes(category.bytesReclaimed))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(
                    "\(StorageFormatting.items(category.itemCount)) "
                        + "item\(category.itemCount == 1 ? "" : "s")"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(category.kind.title), \(StorageFormatting.bytes(category.bytesReclaimed)) reclaimed, "
                + "\(StorageFormatting.items(category.itemCount)) items, "
                + "\(Int((category.share * 100).rounded())) percent of total"
        )
    }
}

/// Thin proportional bar showing one category's share of the lifetime cleaned bytes.
private struct ShareBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.13))
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}
