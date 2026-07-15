import SwiftUI

struct DockerActionResultBanner: View {
    let result: DockerActionResult

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(result.succeeded ? AppTheme.mint : .red)
                .accessibilityHidden(true)
            Text(result.message)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background((result.succeeded ? AppTheme.mint : Color.red).opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}
