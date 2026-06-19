import SwiftUI

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

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 520), spacing: AppTheme.Spacing.large, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraLarge) {
                SettingsHeroView(
                    scanScope: scanScope,
                    reviewItemsEnabled: showReviewItems,
                    threshold: thresholdLabel
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.large) {
                    appearanceSection
                    quickCleanSection
                    projectActivitySection
                    scanningSection
                    safetySection
                    aboutSection
                }
            }
            .padding(AppTheme.Spacing.extraLarge)
            .frame(maxWidth: 1_160, alignment: .leading)
        }
        .background(AppTheme.appBackground)
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings-root")
    }

    private var appearanceSection: some View {
        SettingsPanel(title: "Appearance", icon: "paintbrush.fill", color: AppTheme.indigo) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Theme")
                    .font(.subheadline.weight(.semibold))

                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Theme")

                Text("System follows your current macOS appearance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var quickCleanSection: some View {
        SettingsPanel(title: "Quick Clean", icon: "sparkles", color: AppTheme.accent) {
            NavigationLink {
                SafeToDeleteView()
            } label: {
                HStack(spacing: AppTheme.Spacing.medium) {
                    SettingsIcon(symbol: "checkmark.shield.fill", color: AppTheme.mint)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                        Text("Safe to Delete")
                            .font(.subheadline.weight(.semibold))
                        Text("Choose which categories Quick Clean can include.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(AppTheme.Spacing.medium)
                .background(AppTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Quick Clean category settings")
        }
    }

    private var projectActivitySection: some View {
        SettingsPanel(title: "Project Activity", icon: "folder.badge.gearshape", color: AppTheme.orange) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Text("Consider a project inactive after")
                    .font(.subheadline.weight(.semibold))

                Picker("Inactive project threshold", selection: $inactivityThreshold) {
                    ForEach(InactivityThreshold.allCases) { threshold in
                        Text(threshold.title).tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Inactive projects can be offered for hibernation so regenerable dependencies are reclaimed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scanningSection: some View {
        SettingsPanel(title: "Scanning", icon: "magnifyingglass", color: AppTheme.cyan) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.mediumLarge) {
                Toggle(isOn: $includeExternalVolumes) {
                    SettingToggleLabel(
                        title: "Include connected external volumes",
                        subtitle: "Scan mounted drives in addition to your home folder.",
                        icon: "externaldrive.fill",
                        color: AppTheme.accent
                    )
                }
                .toggleStyle(.switch)

                Toggle(isOn: $showReviewItems) {
                    SettingToggleLabel(
                        title: "Show items that require review",
                        subtitle: "Keep user-created files visible with review labels.",
                        icon: "eye.fill",
                        color: AppTheme.violet
                    )
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("Large file threshold")
                        .font(.subheadline.weight(.semibold))

                    Picker("Large file threshold", selection: $largeFileThresholdMB) {
                        ForEach(LargeFileThreshold.allCases) { threshold in
                            Text(threshold.label)
                                .tag(threshold.megabytes)
                                .accessibilityIdentifier("large-file-threshold-\(threshold.megabytes)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("large-file-threshold-picker")

                    Text("Only files at or above this size appear in Large Files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var safetySection: some View {
        SettingsPanel(title: "Safety", icon: "shield.checkered", color: AppTheme.mint) {
            VStack(spacing: AppTheme.Spacing.small) {
                SettingsValueRow(
                    title: "Deletion policy",
                    value: "Move to Trash",
                    icon: "trash.fill",
                    color: AppTheme.rose
                )
                SettingsValueRow(
                    title: "Confirmation",
                    value: "Always required",
                    icon: "checkmark.shield.fill",
                    color: AppTheme.mint
                )
                SettingsValueRow(
                    title: "Scan scope",
                    value: scanScope,
                    icon: "externaldrive.fill",
                    color: AppTheme.accent
                )
                SettingsValueRow(
                    title: "Review items",
                    value: showReviewItems ? "Visible" : "Hidden",
                    icon: "eye.fill",
                    color: AppTheme.violet
                )
            }
        }
    }

    private var aboutSection: some View {
        SettingsPanel(title: "About", icon: "info.circle.fill", color: AppTheme.teal) {
            VStack(spacing: AppTheme.Spacing.small) {
                SettingsValueRow(
                    title: "Version",
                    value: "0.1.0",
                    icon: "app.badge.fill",
                    color: AppTheme.accent
                )
                SettingsValueRow(
                    title: "Platform",
                    value: "macOS 14.0+",
                    icon: "desktopcomputer",
                    color: AppTheme.indigo
                )
                SettingsValueRow(
                    title: "Scanner",
                    value: "18 category scanners",
                    icon: "list.bullet.rectangle",
                    color: AppTheme.orange
                )
                SettingsValueRow(
                    title: "Cleanup",
                    value: "Trash-based recovery",
                    icon: "arrow.uturn.backward",
                    color: AppTheme.mint
                )
            }
        }
    }

    private var scanScope: String {
        includeExternalVolumes ? "Home + external volumes" : "Home folder only"
    }

    private var thresholdLabel: String {
        (LargeFileThreshold(rawValue: largeFileThresholdMB) ?? .hundredMB).label
    }
}

private struct SettingsHeroView: View {
    let scanScope: String
    let reviewItemsEnabled: Bool
    let threshold: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.large) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Label("Preferences", systemImage: "gearshape.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text("Settings")
                        .font(.largeTitle.bold())

                    Text("Tune scanning, Quick Clean, safety behavior, and the way Storage Cleaner presents results.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.Spacing.large)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 78, height: 78)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityHidden(true)
            }

            HStack(spacing: AppTheme.Spacing.medium) {
                SettingsSummaryPill(title: "Scope", value: scanScope, icon: "externaldrive.fill")
                SettingsSummaryPill(title: "Review", value: reviewItemsEnabled ? "Visible" : "Hidden", icon: "eye.fill")
                SettingsSummaryPill(title: "Large Files", value: threshold, icon: "doc.badge.ellipsis")
            }
        }
        .padding(AppTheme.Spacing.extraLarge)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .shadow(color: Color.primary.opacity(0.045), radius: 10, y: 4)
    }
}

private struct SettingsSummaryPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

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

private struct SettingToggleLabel: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            SettingsIcon(symbol: icon, color: color)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.extraSmall) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            SettingsIcon(symbol: icon, color: color)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: AppTheme.Spacing.medium)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
