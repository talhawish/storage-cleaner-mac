import SwiftUI

/// Standard inline search field used across list screens.
///
/// Replaces the identical hand-rolled search bars that were duplicated in
/// `CategoryDetailView`, the media filter bar, and `AppsView`.
struct SearchField: View {
    @Binding var text: String
    var prompt: String = "Search…"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
