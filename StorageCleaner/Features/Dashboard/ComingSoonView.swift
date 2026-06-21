import SwiftUI

struct ComingSoonView: View {
    let section: AppSection

    var body: some View {
        EmptyStateView(
            title: section.title,
            message: "This area is part of the next implementation milestone.",
            systemImage: section.symbolName,
            tint: AppTheme.accent
        )
        .navigationTitle(section.title)
    }
}
