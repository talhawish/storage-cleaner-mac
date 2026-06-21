import SwiftUI

/// A flow layout that wraps items into rows based on available width and
/// centres every row — including partial rows. Use when you want the
/// responsive behaviour of a grid (items wrap as the window resizes) but
/// also want the last row centred when it doesn't fill the available width.
struct CenteredFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 12) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height }
            + CGFloat(max(0, rows.count - 1)) * spacing
        let width = rows.map(\.width).max() ?? 0
        return CGSize(
            width: proposal.width ?? min(width, maxWidth),
            height: height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var currentY = bounds.minY
        for row in rows {
            let currentX = bounds.minX + (bounds.width - row.width) / 2
            for item in row.items {
                let size = item.size
                item.subview.place(
                    at: CGPoint(x: currentX + item.xOffset, y: currentY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
            }
            currentY += row.height + spacing
        }
    }

    // MARK: - Row arrangement

    private struct RowItem {
        let subview: LayoutSubview
        let size: CGSize
        let xOffset: CGFloat
    }

    private struct Row {
        var items: [RowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needsSpacing = !current.items.isEmpty
            let projectedWidth = current.width
                + (needsSpacing ? spacing : 0)
                + size.width

            if projectedWidth > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }

            let itemX = current.width + (current.items.isEmpty ? 0 : spacing)
            current.items.append(RowItem(subview: subview, size: size, xOffset: itemX))
            current.width = itemX + size.width
            current.height = max(current.height, size.height)
        }

        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
