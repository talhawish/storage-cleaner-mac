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
///
/// Visually the panel uses a subtle gradient border (matching the
/// paywall's `PlanCard.featured` rhythm) so the subscription section
/// reads as a premium surface, not a plain settings row.
struct SubscriptionSettingsSection: View {
    @Bindable var controller: SubscriptionController

    var body: some View {
        SettingsSectionCard(
            title: "Subscription",
            subtitle: "Manage your plan and unlock Pro features.",
            icon: "sparkles",
            tint: AppTheme.accent
        ) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.mediumLarge) {
                currentPlanRow
                actionRow
                footerNote
            }
        }
        .accessibilityIdentifier("settings-subscription-panel")
    }

    // MARK: - Subviews

    private var currentPlanRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            planIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Current plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if controller.currentEntitlement.isPro {
                        Text("Pro")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.accent))
                    }
                }
                Text(planTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            if controller.currentEntitlement.isPro {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.mint)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.mint)
                    }
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

    private var planIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(planIconColor.opacity(0.14))
            Image(systemName: planIconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(planIconColor)
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
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
