import SwiftUI

/// The top bar of the Quick Clean modal. Composed of an icon tile, a
/// two-line title block, an optional Settings link, and the close button.
/// Lifted out of `QuickCleanView` so the phase machine file stays small.
struct QuickCleanHeader: View {
    let subtitle: String
    let showsSettingsButton: Bool
    let onSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Quick Clean")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if showsSettingsButton {
                Button {
                    onSettings()
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .accessibilityHint("Open Safe to Delete settings")
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.secondary.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
