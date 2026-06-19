import SwiftUI

/// "Where your space is going" — the grid of domain tiles that leads the Overview results, giving a
/// quick map of the largest storage groups before the detailed rows.
struct SpaceBreakdownGrid: View {
    let tiles: [StorageOverview.DomainUsage]
    let onSelect: (StorageDomain) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 320), spacing: AppTheme.Spacing.mediumLarge)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            SectionHeader(
                title: "Where your space is going",
                subtitle: "Your largest storage groups",
                systemImage: "chart.pie.fill"
            )

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.mediumLarge) {
                ForEach(tiles) { tile in
                    DomainUsageTile(usage: tile) { onSelect(tile.domain) }
                }
            }
        }
    }
}
