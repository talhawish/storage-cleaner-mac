import SwiftUI

struct ActivityBadge: View {
    let status: ProjectActivityStatus

    var body: some View {
        HStack(spacing: AppTheme.Spacing.extraSmall) {
            Image(systemName: status.icon)
                .font(.caption)
                .accessibilityHidden(true)
            Text(status.label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, AppTheme.Spacing.extraSmall)
        .background(Color(hex: status.color).opacity(0.15), in: Capsule())
        .foregroundStyle(Color(hex: status.color))
    }
}
