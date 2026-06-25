import SwiftUI

/// Slim footer rendered at the bottom of the in-app Settings page. A
/// single-line trust strip with version, scanner count, and platform
/// metadata. Keeps the page from ending abruptly and makes "About"
/// information discoverable without taking up a full Settings card.
struct SettingsFooterBar: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            SettingsFooterItem(systemImage: "app.badge.fill", text: "Version 0.1.0", tint: AppTheme.accent)
            SettingsFooterDivider()
            SettingsFooterItem(
                systemImage: "list.bullet.rectangle",
                text: "33 category scanners",
                tint: AppTheme.orange
            )
            SettingsFooterDivider()
            SettingsFooterItem(
                systemImage: "macbook.gen2",
                text: "macOS 14.0+",
                tint: AppTheme.indigo
            )
            SettingsFooterDivider()
            SettingsFooterItem(
                systemImage: "hand.raised.fill",
                text: "100% on-device",
                tint: AppTheme.mint
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.large)
        .padding(.vertical, AppTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SettingsFooterItem: View {
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsFooterDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.hairline)
            .frame(width: 1, height: 12)
            .accessibilityHidden(true)
    }
}
