import SwiftUI

extension View {
    /// Shows a native macOS popover tooltip immediately when the view is hovered,
    /// without the system delay that `.help()` introduces.
    func tooltip(_ text: String) -> some View {
        modifier(InstantTooltip(text: text))
    }
}

private struct InstantTooltip: ViewModifier {
    let text: String
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
            }
            .popover(isPresented: $isHovered, arrowEdge: .trailing) {
                Text(text)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.primary)
            }
    }
}
