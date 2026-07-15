import SwiftUI

/// Legal documents remain available independently of StoreKit so a user can
/// review them even when products fail to load or no purchase is in progress.
struct LegalSettingsSection: View {
    var body: some View {
        SettingsSectionCard(
            title: "Legal",
            subtitle: "Review the terms that govern the app and how your data is handled.",
            icon: "doc.text.fill",
            tint: AppTheme.indigo
        ) {
            VStack(spacing: AppTheme.Spacing.small) {
                Link(destination: AppLinks.terms) {
                    Label("Terms of Use (EULA)", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("settings-terms-link")

                Divider()

                Link(destination: AppLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("settings-privacy-link")
            }
            .buttonStyle(.link)
        }
        .accessibilityIdentifier("settings-legal-panel")
    }
}
