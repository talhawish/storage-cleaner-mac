import SwiftUI

struct ComingSoonView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.symbolName)
        } description: {
            Text("This area is part of the next implementation milestone.")
        }
        .navigationTitle(section.title)
    }
}
