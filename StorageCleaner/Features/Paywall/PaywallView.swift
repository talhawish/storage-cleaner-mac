import SwiftUI

/// The paywall sheet. Presented as a scrollable, header-pinned modal when the user
/// attempts a gated action (currently: any cleanup) or opens the
/// Subscription section in Settings.
///
/// Layout — single column, hero-first, matching the rest of the
/// app's design language (aurora background, eyebrow chip, gradient
/// headline, value-prop highlights, and a 3-card plan grid):
///
/// ```
///  ┌──────────────────────────────────────────────┐
///  │ Pinned header (icon, title, close)            │
///  ├──────────────────────────────────────────────┤
///  │ Scrollable content                            │
///  │   Aurora hero                                 │
///  │   [PRO eyebrow chip]                          │
///  │   [gradient headline]                         │
///  │   [subtitle]                                  │
///  │   [3 value-prop highlights in a row]          │
///  ├──────────────────────────────────────────────┤
///  │ 3 plan cards in a row (middle highlighted)    │
///  ├──────────────────────────────────────────────┤
///  │ Trust strip (3 inline items)                  │
///  ├──────────────────────────────────────────────┤
///  │ Footer (Restore, Terms, Privacy, auto-renew)  │
///  └──────────────────────────────────────────────┘
/// ```
///
/// The fixed header keeps dismissal available at every window height. Everything
/// below it shares one vertical scroll container so trackpad, mouse-wheel, keyboard,
/// and VoiceOver scrolling all follow the same predictable path.
struct PaywallView: View {
    @Bindable var viewModel: PaywallViewModel
    var body: some View {
        AppModal(
            idealWidth: 880,
            minHeight: 500,
            idealHeight: 640,
            maxHeight: 700
        ) {
            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                        planSection
                        restoreLink
                        trustStrip
                        PaywallFooterBar()
                    }
                }
                .scrollIndicators(.automatic)
                .accessibilityIdentifier("paywall-scroll-view")
            }
        }
        .accessibilityIdentifier("paywall-root")
        .task {
            await viewModel.loadProducts()
        }
    }

    // MARK: - Header

    private var header: some View {
        AppModalHeader(
            iconSystemName: "sparkles",
            iconTint: AppTheme.accent,
            title: "Storage Cleaner Pro",
            subtitle: "Unlock the full power",
            showsCloseButton: true
        )
    }

    // MARK: - Hero

    @ViewBuilder private var heroSection: some View {
        PaywallHero(
            eyebrowIcon: "wand.and.stars",
            eyebrowText: "Storage Cleaner Pro",
            headline: "Reclaim your disk space.",
            subtitle: "Pro turns every scan into a one-tap cleanup — across every category,"
                + " with smart previews and Trash-based safety.",
            highlights: heroHighlights
        )
    }

    private var heroHighlights: [PaywallHero.Highlight] {
        [
            PaywallHero.Highlight(
                id: "trash",
                icon: "trash.fill",
                title: "Move to Trash",
                tint: AppTheme.accent
            ),
            PaywallHero.Highlight(
                id: "duplicates",
                icon: "doc.on.doc.fill",
                title: "Find duplicates",
                tint: AppTheme.cyan
            ),
            PaywallHero.Highlight(
                id: "ai",
                icon: "sparkles",
                title: "Detect AI caches",
                tint: AppTheme.violet
            ),
            PaywallHero.Highlight(
                id: "review",
                icon: "shield.lefthalf.filled",
                title: "Review previews",
                tint: AppTheme.mint
            )
        ]
    }

    // MARK: - Plans

    @ViewBuilder private var planSection: some View {
        VStack(spacing: 10) {
            bannerView
            if viewModel.isLoadingProducts, viewModel.plans.isEmpty {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        PlanCardSkeleton()
                    }
                }
            } else if viewModel.plans.isEmpty {
                PaywallProductUnavailableView {
                    Task { await viewModel.loadProducts() }
                }
            } else {
                HStack(spacing: 12) {
                    ForEach(sortedPlans) { plan in
                        PlanCard(
                            plan: plan,
                            variant: plan.id == viewModel.highlightedPlanID ? .featured : .standard,
                            isCurrentPlan: plan.entitlement == viewModel.currentEntitlement,
                            isPurchasing: viewModel.purchasingProductID == plan.id,
                            onPurchase: {
                                Task { await viewModel.purchase(productID: plan.id) }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    @ViewBuilder private var bannerView: some View {
        switch viewModel.banner {
        case .none:
            EmptyView()
        case let .success(message):
            PaywallBanner(tint: AppTheme.mint, systemImage: "checkmark.circle.fill", text: message)
        case let .error(message):
            PaywallBanner(tint: AppTheme.rose, systemImage: "exclamationmark.triangle.fill", text: message)
        case let .info(message):
            PaywallBanner(tint: AppTheme.accent, systemImage: "info.circle.fill", text: message)
        }
    }

    /// Renders plans in the canonical order (monthly → yearly →
    /// lifetime). The paywall relies on this order so the middle
    /// card (yearly) is the one we highlight as "Best Value".
    private var sortedPlans: [SubscriptionPlan] {
        let order = SubscriptionProductID.all
        return viewModel.plans.sorted { lhs, rhs in
            let leftIndex = order.firstIndex(of: lhs.id) ?? .max
            let rightIndex = order.firstIndex(of: rhs.id) ?? .max
            return leftIndex < rightIndex
        }
    }

    // MARK: - Restore link

    private var restoreLink: some View {
        PaywallRestoreLink(
            isRestoring: viewModel.restoring,
            onRestore: {
                Task { await viewModel.restore() }
            }
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Trust strip

    private var trustStrip: some View {
        CenteredFlowLayout(spacing: 18) {
            ForEach(trustItems) { item in
                HStack(spacing: 6) {
                    Image(systemName: item.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.tint)
                        .accessibilityHidden(true)
                    Text(item.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(AppTheme.appBackground)
    }

    // MARK: - Static content

    private struct TrustItem: Identifiable, Equatable {
        let id: String
        let systemImage: String
        let text: String
        let tint: Color
    }

    private var trustItems: [TrustItem] {
        [
            TrustItem(id: "secure", systemImage: "lock.fill", text: "Secure via Apple", tint: AppTheme.mint),
            TrustItem(id: "cancel", systemImage: "arrow.uturn.backward", text: "Cancel anytime", tint: AppTheme.accent),
            TrustItem(id: "private", systemImage: "hand.raised.fill", text: "100% on-device", tint: AppTheme.violet)
        ]
    }
}
