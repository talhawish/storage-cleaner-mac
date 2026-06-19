import SwiftUI

struct ComingSoonView: View {
    let section: AppSection

    var body: some View {
        AnimatedEmptyState(
            title: section.title,
            message: "This area is part of the next implementation milestone.",
            systemImage: section.symbolName
        )
        .navigationTitle(section.title)
    }
}
