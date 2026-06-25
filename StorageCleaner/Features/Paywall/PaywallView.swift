import SwiftUI

/// The paywall sheet. Presented as a ~880×680 modal when the user
/// attempts a gated action (currently: any cleanup) or opens the
/// Subscription section in Settings.
///
/// Layout — single column, hero-first, matching the rest of the
/// app's design language (aurora background, eyebrow chip, gradient
/// headline, value-prop highlights, and a 3-card plan grid):
///
/// ```
///  ┌──────────────────────────────────────────────┐
///  │ Header (icon, title, close)                   │
///  ├──────────────────────────────────────────────┤
///  │ Aurora hero                                   │
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
/// The view is a pure renderer: it never mutates state directly,
/// always going through `viewModel`. The two callbacks it owns —
/// `onDismiss` and `onEntitlementUpgraded` — bubble up to the
/// caller (Dashboard / Settings) which decides what closing the
/// paywall means.
struct PaywallView: View {
    @Bindable var viewModel: PaywallViewModel
    let onTermsTapped: () -> Void
    let onPrivacyTapped: () -> Void
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        AppModal(
            idealWidth: 880,
            minHeight: 640,
            idealHeight: 680,
            maxHeight: 820
        ) {
            VStack(spacing: 0) {
                header
                Divider()
                heroSection
                planSection
                restoreLink
                trustStrip
                PaywallFooterBar(
                    onTermsTapped: onTermsTapped,
                    onPrivacyTapped: onPrivacyTapped
                )
            }
        }
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
        HStack(spacing: 18) {
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
                if item.id != trustItems.last?.id {
                    Spacer(minLength: 0)
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

// MARK: - Hero

/// The paywall's hero section. Mirrors the design language of the
/// dashboard's `WelcomeHeroView` and the per-section
/// `InitialStateView` — aurora background, eyebrow chip, gradient
/// headline, value-prop highlights — but compressed for the
/// modal-sized canvas.
///
/// All motion honors `accessibilityReduceMotion`: when the user has
/// reduced motion enabled, the aurora blobs sit at their rest
/// position and the rotation animation collapses.
private struct PaywallHero: View {
    struct Highlight: Identifiable, Equatable {
        let id: String
        let icon: String
        let title: String
        let tint: Color
    }

    let eyebrowIcon: String
    let eyebrowText: String
    let headline: String
    let subtitle: String
    let highlights: [Highlight]

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var didAppear = false
    @State private var ringRotation = 0.0
    @State private var blobPhase: Double = 0

    var body: some View {
        ZStack {
            backgroundLayer
            content
        }
        .frame(maxWidth: .infinity)
        .clipShape(Rectangle())
        .onAppear(perform: startAnimations)
    }

    // MARK: Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.10),
                    AppTheme.cyan.opacity(0.06),
                    AppTheme.violet.opacity(0.08),
                    AppTheme.appBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if !reduceMotion {
                Circle()
                    .fill(AppTheme.accent.opacity(0.35))
                    .frame(width: 240, height: 240)
                    .blur(radius: 90)
                    .offset(
                        x: didAppear ? cos(blobPhase) * 60 : 0,
                        y: didAppear ? sin(blobPhase * 0.7) * 24 : 0
                    )

                Circle()
                    .fill(AppTheme.violet.opacity(0.30))
                    .frame(width: 200, height: 200)
                    .blur(radius: 90)
                    .offset(
                        x: didAppear ? cos(blobPhase * 0.6 + 2.0) * 50 : 0,
                        y: didAppear ? sin(blobPhase * 0.8 + 1.0) * 30 : 0
                    )
            }
        }
    }

    // MARK: Content

    private var content: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.extraLarge) {
            textStack
            Spacer(minLength: 8)
            orb
                .frame(width: 130, height: 130)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow
            headlineLabel
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            highlightsRow
                .padding(.top, 6)
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var eyebrow: some View {
        HStack(spacing: 6) {
            Image(systemName: eyebrowIcon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text(eyebrowText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .tracking(0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(AppTheme.accent.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.5)
        }
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.05), value: didAppear)
    }

    private var headlineLabel: some View {
        Text(headline)
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .lineSpacing(1)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.primary,
                        Color.primary.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(didAppear ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.10), value: didAppear)
    }

    private var highlightsRow: some View {
        HStack(spacing: 8) {
            ForEach(highlights) { highlight in
                HighlightChip(highlight: highlight)
            }
        }
        .opacity(didAppear ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.18), value: didAppear)
    }

    // MARK: Orb

    private var orb: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            AppTheme.accent.opacity(0.0),
                            AppTheme.accent.opacity(0.75),
                            AppTheme.cyan.opacity(0.65),
                            AppTheme.violet.opacity(0.65),
                            AppTheme.accent.opacity(0.0)
                        ],
                        center: .center
                    ),
                    lineWidth: 1.4
                )
                .rotationEffect(.degrees(reduceMotion ? 0 : ringRotation))
                .blur(radius: 0.4)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 92, height: 92)
                .overlay {
                    Circle().strokeBorder(AppTheme.accent.opacity(0.30), lineWidth: 1)
                }

            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
        }
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 24, y: 8)
    }

    // MARK: Animation

    private func startAnimations() {
        if reduceMotion {
            didAppear = true
            return
        }
        withAnimation(.snappy(duration: 0.5).delay(0.05)) {
            didAppear = true
        }
        withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            blobPhase = .pi * 2
        }
    }
}

/// A single value-prop chip used in the hero's highlight row.
/// Matches the eyebrow chip's visual rhythm so the two read as a
/// family: tinted capsule, small icon, short label.
private struct HighlightChip: View {
    let highlight: PaywallHero.Highlight

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: highlight.icon)
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(highlight.title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(highlight.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(highlight.tint.opacity(0.12), in: Capsule())
        .overlay {
            Capsule().stroke(highlight.tint.opacity(0.25), lineWidth: 0.5)
        }
    }
}

// MARK: - Banner

/// A short status banner shown above the plan row. Tint + icon +
/// text. Sized for the new compact layout.
private struct PaywallBanner: View {
    let tint: Color
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.smooth, value: text)
    }
}

// MARK: - Skeleton

/// Loading placeholder for a `PlanCard`. Card-shaped, not pill-
/// shaped — the old generic pills read as "empty" rather than
/// "loading", which the previous design got called out for.
private struct PlanCardSkeleton: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule()
                .fill(gradient)
                .frame(width: 60, height: 12)
            Capsule()
                .fill(gradient)
                .frame(width: 90, height: 26)
            Capsule()
                .fill(gradient)
                .frame(width: 60, height: 12)
            Spacer(minLength: 0)
            Capsule()
                .fill(gradient)
                .frame(height: 30)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.subtleSurface,
                AppTheme.subtleSurface.opacity(0.7),
                AppTheme.subtleSurface
            ],
            startPoint: UnitPoint(x: phase - 1, y: 0.5),
            endPoint: UnitPoint(x: phase, y: 0.5)
        )
    }
}
