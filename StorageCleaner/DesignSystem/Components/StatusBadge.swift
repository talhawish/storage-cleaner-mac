import SwiftUI

struct StatusBadge: View {
    let safety: CleanupSafety

    var body: some View {
        Label(safety.title, systemImage: safety == .safe ? "checkmark.shield.fill" : "eye.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(safety == .safe ? AppTheme.mint : AppTheme.orange)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                (safety == .safe ? AppTheme.mint : AppTheme.orange).opacity(0.12),
                in: Capsule()
            )
            .accessibilityLabel(safety.title)
    }
}
