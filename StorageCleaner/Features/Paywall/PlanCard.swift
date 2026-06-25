import SwiftUI

/// One selectable plan tile in the paywall. The paywall renders
/// three of these side-by-side; the middle one (yearly) is the
/// "Best Value" highlight.
///
/// Two visual variants:
/// - `.featured`: gradient border (accent → cyan → violet), badge
///   above the price, subtle inner glow, taller — the "look at me"
///   card.
/// - `.standard`: hairline border, no badge — the supporting cast.
///
/// Renders the plan name, big price + period, the plan's marketing
/// description, a per-plan savings chip, and a primary action
/// button. The button is disabled with a "Current Plan" label when
/// this is the user's active plan and shows an inline spinner when
/// its purchase is in flight.
struct PlanCard: View {
    enum Variant: Sendable, Equatable {
        case featured
        case standard
    }

    let plan: SubscriptionPlan
    let variant: Variant
    let isCurrentPlan: Bool
    let isPurchasing: Bool
    let onPurchase: () -> Void

    private var actionTitle: String {
        if isCurrentPlan {
            return "Current Plan"
        }
        switch plan.entitlement {
        case .monthly: return "Start Monthly"
        case .yearly: return "Start Yearly"
        case .lifetime: return "Buy Lifetime"
        case .free: return "Choose"
        }
    }

    private var primaryTint: Color {
        switch plan.entitlement {
        case .monthly: AppTheme.cyan
        case .yearly: AppTheme.accent
        case .lifetime: AppTheme.amber
        case .free: AppTheme.accent
        }
    }

    var body: some View {
        cardSurface
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
            .overlay(alignment: .top) {
                if plan.entitlement == .yearly {
                    bestValueRibbon
                        .offset(y: -12)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("plan-card-\(plan.entitlement.rawValue)")
    }

    // MARK: - Card surface

    @ViewBuilder private var cardSurface: some View {
        if variant == .featured {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.85),
                                AppTheme.cyan.opacity(0.70),
                                AppTheme.violet.opacity(0.80)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )

                cardContent
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                            .stroke(AppTheme.hairline.opacity(0.4), lineWidth: 0.5)
                    )
            }
            .shadow(color: AppTheme.accent.opacity(0.20), radius: 18, y: 8)
        } else {
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .fill(AppTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            priceBlock
            Text(plan.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
            actionButton
        }
        .padding(16)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(plan.entitlement.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
            Spacer(minLength: 0)
            sideBadge
        }
    }

    @ViewBuilder private var sideBadge: some View {
        switch plan.entitlement {
        case .lifetime:
            Text("Pay once")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.amber)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(AppTheme.amber.opacity(0.14)))
                .overlay {
                    Capsule().stroke(AppTheme.amber.opacity(0.25), lineWidth: 0.5)
                }
        case .monthly, .yearly, .free:
            EmptyView()
        }
    }

    // MARK: - Price

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(plan.displayPrice)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .accessibilityHidden(true)
                if let period = plan.period, period != .lifetime {
                    Text(periodSuffix(for: period))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            Text(priceQualifier)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(priceAccessibilityLabel)
    }

    private var priceQualifier: String {
        switch plan.entitlement {
        case .monthly: return "Billed monthly"
        case .yearly: return "$2.50 / mo · billed yearly"
        case .lifetime: return "One-time, yours forever"
        case .free: return ""
        }
    }

    private func periodSuffix(for period: SubscriptionPlan.BillingPeriod) -> String {
        switch period {
        case .monthly: return "/mo"
        case .yearly: return "/yr"
        case .lifetime: return ""
        }
    }

    private var priceAccessibilityLabel: String {
        guard let period = plan.period else { return plan.displayPrice }
        let unit: String
        switch period {
        case .monthly: unit = "per month"
        case .yearly: unit = "per year"
        case .lifetime: unit = "one-time"
        }
        return "\(plan.displayPrice) \(unit)"
    }

    // MARK: - Action

    private var actionButton: some View {
        Button(action: onPurchase) {
            HStack(spacing: 6) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text(actionTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(primaryTint)
        .disabled(isPurchasing || isCurrentPlan)
        .help(isCurrentPlan ? "You're already on this plan" : actionTitle)
    }

    // MARK: - Ribbon

    /// "Best Value" ribbon that hangs off the top of the featured
    /// card. Renders above the card (negative offset) so the
    /// gradient border isn't broken by the chip.
    private var bestValueRibbon: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("Best Value")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accent,
                            AppTheme.violet
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: AppTheme.accent.opacity(0.30), radius: 8, y: 3)
    }
}
