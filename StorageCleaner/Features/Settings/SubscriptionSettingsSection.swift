import SwiftUI

/// The "Subscription" panel inside the in-app Settings screen.
/// Reads its entitlement + actions from a `SubscriptionController`
/// passed in by the parent so the panel, the dashboard, and the
/// paywall sheet all share one source of truth.
///
/// Renders two states:
/// - **Free**: shows the current plan ("Free") and a single
///   "Upgrade to Pro" button that opens the paywall sheet.
///   Restore Purchases is intentionally **not** here — it lives
///   inside the paywall (`PaywallRestoreLink`) so it's discoverable
///   in the same surface as the prices, not in two places.
/// - **Pro**: shows the current plan ("Monthly" / "Yearly" /
///   "Lifetime") with a status pill, a "Manage Subscription" button
///   that hands control to AppKit, and a "Change Plan" button that
///   opens the paywall sheet.
struct SubscriptionSettingsSection: View {
    @Bindable var controller: SubscriptionController

    var body: some View {
        SettingsPanel(
            title: "Subscription",
            icon: "sparkles",
            color: AppTheme.accent
        ) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                currentPlanRow
                actionRow
                footerNote
            }
        }
        .accessibilityIdentifier("settings-subscription-panel")
    }

    // MARK: - Subviews

    private var currentPlanRow: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            SettingsIcon(symbol: planIconName, color: planIconColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current plan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if controller.currentEntitlement.isPro {
                        Text("Pro")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(AppTheme.accent)
                            )
                    }
                }
                Text(planTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            if controller.currentEntitlement.isPro {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.mint)
                    Text(planSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.subtleSurface)
        )
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            primaryActionButton
            secondaryActionButton
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var primaryActionButton: some View {
        if controller.currentEntitlement.isPro {
            Button {
                controller.showManageSubscriptions()
            } label: {
                Label("Manage Subscription", systemImage: "creditcard")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityIdentifier("settings-subscription-manage")
        } else {
            Button {
                controller.presentPaywall(trigger: .manualOpen)
            } label: {
                Label("Upgrade to Pro", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(AppTheme.accent)
            .accessibilityIdentifier("settings-subscription-upgrade")
        }
    }

    @ViewBuilder private var secondaryActionButton: some View {
        if controller.currentEntitlement.isPro {
            Button {
                controller.presentPaywall(trigger: .manualOpen)
            } label: {
                Label("Change Plan", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityIdentifier("settings-subscription-change")
        }
        // For free users the Settings row stays single-button —
        // Restore Purchases lives inside the paywall itself
        // (`PaywallRestoreLink`) so it's discoverable in the same
        // surface as the prices, not in two places.
    }

    private var footerNote: some View {
        Text(
            "Scanning is always free. Pro unlocks moving files to the Trash across every category,"
                + " including duplicates, large files, and AI caches."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Derived

    private var planTitle: String {
        switch controller.currentEntitlement {
        case .free: "Free"
        case .monthly: "Pro · Monthly"
        case .yearly: "Pro · Yearly"
        case .lifetime: "Pro · Lifetime"
        }
    }

    private var planSubtitle: String {
        switch controller.currentEntitlement {
        case .free: "Scanning only"
        case .monthly: "Renews monthly"
        case .yearly: "Renews yearly"
        case .lifetime: "One-time purchase"
        }
    }

    private var planIconName: String {
        controller.currentEntitlement.isPro ? "checkmark.seal.fill" : "circle.dashed"
    }

    private var planIconColor: Color {
        controller.currentEntitlement.isPro ? AppTheme.mint : .gray
    }
}

// Re-export the SettingsPanel / SettingsIcon from the same module
// so this file stands alone. The originals are fileprivate in
// InAppSettingsView.swift; we re-implement the visual primitives
// inline so the paywall module can ship independently.
private struct SettingsPanel<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.mediumLarge) {
            HStack(spacing: AppTheme.Spacing.small) {
                SettingsIcon(symbol: icon, color: color)
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .shadow(color: Color.primary.opacity(0.045), radius: 10, y: 4)
    }
}

private struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}
