import SwiftUI

/// Horizontal row of Overview tip cards. Renders nothing when there are no tips, so the Overview
/// never shows an empty placeholder.
struct OverviewTipsCarousel: View {
    let tips: [OverviewTip]
    let onAction: (OverviewTip) -> Void

    var body: some View {
        if !tips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ForEach(tips) { tip in
                        OverviewTipCard(tip: tip, onAction: onAction)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
