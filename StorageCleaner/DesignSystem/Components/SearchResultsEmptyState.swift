import SwiftUI

/// A consistent, actionable result for a valid search that matches nothing.
/// Keeping this separate from post-scan empty states makes it clear that the
/// underlying data still exists and gives the user an immediate recovery action.
struct SearchResultsEmptyState: View {
    let itemLabel: String
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        EmptyStateView(
            title: "No matches",
            message: "No \(itemLabel) match “\(searchText)”. Try a different search or clear the filter.",
            systemImage: "magnifyingglass",
            tint: AppTheme.accent,
            actionTitle: "Clear Search",
            action: onClear
        )
    }
}
