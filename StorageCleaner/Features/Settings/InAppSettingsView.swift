import SwiftUI

/// The in-app Settings page reachable from the sidebar.
///
/// Layout — single column, hero-first, matching the rest of the app's
/// design language:
///
/// ```
///  ┌──────────────────────────────────────────────┐
///  │ Settings hero (aurora, headline, status pills)│
///  ├──────────────────────────────────────────────┤
///  │ Subscription                                  │
///  │ Appearance                                    │
///  │ Quick Clean                                   │
///  │ Project Activity                              │
///  │ Scanning                                      │
///  │ Safety                                        │
///  ├──────────────────────────────────────────────┤
///  │ Footer (version, scanners, on-device)         │
///  └──────────────────────────────────────────────┘
/// ```
///
/// The view is a pure renderer. All settings are stored via `@AppStorage`
/// and the `SubscriptionController` is the single source of truth for the
/// Pro/Free entitlement state.
struct InAppSettingsView: View {
    @AppStorage("includeExternalVolumes")
    private var includeExternalVolumes = false
    @AppStorage("showReviewItems")
    private var showReviewItems = true
    @AppStorage(LargeFileThreshold.storageKey)
    private var largeFileThresholdMB = LargeFileThreshold.defaultMegabytes
    @AppStorage("appearanceMode")
    private var appearanceMode: AppearanceMode = .system
    @AppStorage("inactivityThreshold")
    private var inactivityThreshold: InactivityThreshold = .oneMonth
    @Bindable var subscriptionController: SubscriptionController

    private let contentWidth: CGFloat = 880

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraLarge) {
                SettingsHeroView(
                    scanScope: scanScope,
                    reviewItemsEnabled: showReviewItems,
                    largeFileThreshold: thresholdLabel
                )
                .accessibilityIdentifier("settings-hero")

                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    SubscriptionSettingsSection(controller: subscriptionController)
                    appearanceSection
                    quickCleanSection
                    projectActivitySection
                    scanningSection
                    safetySection
                }

                SettingsFooterBar()
            }
            .padding(.horizontal, AppTheme.Spacing.extraLarge)
            .padding(.vertical, AppTheme.Spacing.extraLarge)
            .frame(maxWidth: contentWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(AppTheme.appBackground)
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings-root")
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        SettingsSectionCard(
            title: "Appearance",
            subtitle: "Choose how Storage Cleaner looks on your Mac.",
            icon: "paintbrush.fill",
            tint: AppTheme.indigo
        ) {
            SettingsSegmentedRow(
                title: "Theme",
                subtitle: "System follows your current macOS appearance.",
                icon: "circle.lefthalf.filled",
                tint: AppTheme.indigo,
                selection: $appearanceMode,
                options: AppearanceMode.allCases
            ) { mode in
                Label(mode.title, systemImage: mode.symbolName).tag(mode)
            }
        }
    }

    private var quickCleanSection: some View {
        SettingsSectionCard(
            title: "Quick Clean",
            subtitle: "One-tap cleanup of files that are safe to remove.",
            icon: "sparkles",
            tint: AppTheme.accent
        ) {
            SettingsNavigationRow(
                title: "Safe to Delete",
                subtitle: "Choose which categories Quick Clean can include.",
                icon: "checkmark.shield.fill",
                tint: AppTheme.mint,
                destination: SettingsNavigationDestination(view: AnyView(SafeToDeleteView())),
                accessibilityIdentifier: "settings-quick-clean-safe"
            )
        }
    }

    private var projectActivitySection: some View {
        SettingsSectionCard(
            title: "Project Activity",
            subtitle: "How long a project must sit before it is offered for hibernation.",
            icon: "folder.badge.gearshape",
            tint: AppTheme.orange
        ) {
            SettingsSegmentedRow(
                title: "Consider a project inactive after",
                subtitle:
                    "Inactive projects can be offered for hibernation so regenerable "
                    + "dependencies are reclaimed.",
                icon: "clock.badge.checkmark",
                tint: AppTheme.orange,
                selection: $inactivityThreshold,
                options: InactivityThreshold.allCases
            ) { threshold in
                Text(threshold.title).tag(threshold)
            }
        }
    }

    private var scanningSection: some View {
        SettingsSectionCard(
            title: "Scanning",
            subtitle: "What to include in every scan and how to surface results.",
            icon: "magnifyingglass",
            tint: AppTheme.cyan
        ) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.mediumLarge) {
                SettingsToggleRow(
                    title: "Include connected external volumes",
                    subtitle: "Scan mounted drives in addition to your home folder.",
                    icon: "externaldrive.fill",
                    tint: AppTheme.accent,
                    isOn: $includeExternalVolumes,
                    accessibilityIdentifier: "settings-include-external-volumes"
                )

                SettingsToggleRow(
                    title: "Show items that require review",
                    subtitle: "Keep user-created files visible with review labels.",
                    icon: "eye.fill",
                    tint: AppTheme.violet,
                    isOn: $showReviewItems,
                    accessibilityIdentifier: "settings-show-review-items"
                )

                SettingsSegmentedRow(
                    title: "Large file threshold",
                    subtitle: "Only files at or above this size appear in Large Files.",
                    icon: "doc.badge.ellipsis",
                    tint: AppTheme.cyan,
                    selection: largeFileThresholdBinding,
                    options: LargeFileThreshold.allCases,
                    accessibilityIdentifier: "large-file-threshold-picker"
                ) { threshold in
                    Text(threshold.label)
                        .tag(threshold)
                        .accessibilityIdentifier("large-file-threshold-\(threshold.megabytes)")
                }
            }
        }
    }

    private var safetySection: some View {
        SettingsSectionCard(
            title: "Safety",
            subtitle: "How Storage Cleaner handles deletions.",
            icon: "shield.checkered",
            tint: AppTheme.mint
        ) {
            VStack(spacing: AppTheme.Spacing.small) {
                SettingsValueRow(
                    title: "Deletion policy",
                    value: "Move to Trash",
                    icon: "trash.fill",
                    tint: AppTheme.rose
                )
                Divider().padding(.leading, 44)
                SettingsValueRow(
                    title: "Confirmation",
                    value: "Always required",
                    icon: "checkmark.shield.fill",
                    tint: AppTheme.mint
                )
                Divider().padding(.leading, 44)
                SettingsValueRow(
                    title: "Scan scope",
                    value: scanScope,
                    icon: "externaldrive.fill",
                    tint: AppTheme.accent
                )
                Divider().padding(.leading, 44)
                SettingsValueRow(
                    title: "Review items",
                    value: showReviewItems ? "Visible" : "Hidden",
                    icon: "eye.fill",
                    tint: AppTheme.violet
                )
            }
        }
    }

    // MARK: - Derived

    private var scanScope: String {
        includeExternalVolumes ? "Home + external volumes" : "Home folder only"
    }

    private var thresholdLabel: String {
        threshold.label
    }

    private var threshold: LargeFileThreshold {
        LargeFileThreshold(rawValue: largeFileThresholdMB) ?? .hundredMB
    }

    /// The `SettingsSegmentedRow` is generic over an `Identifiable` value
    /// type. `LargeFileThreshold` is `Identifiable` by raw MB value, so we
    /// bind a `LargeFileThreshold` to keep the API natural on both ends.
    private var largeFileThresholdBinding: Binding<LargeFileThreshold> {
        Binding(
            get: { threshold },
            set: { largeFileThresholdMB = $0.megabytes }
        )
    }
}
