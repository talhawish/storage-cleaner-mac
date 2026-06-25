import SwiftUI

// Shared visual primitives used by every screen under `Features/Settings/`
// and by `SubscriptionSettingsSection`. Centralising them removes the
// previous duplication where the same `SettingsPanel` and `SettingsIcon`
// were re-declared in two files.

/// Section card for the in-app Settings surface. A rounded surface with a
/// small icon tile, a title, an optional supporting line, and a content
/// slot. Use for every grouped block of controls (Appearance, Scanning,
/// Subscription, About) so the rhythm stays consistent across the page.
struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.mediumLarge) {
            header
            content
        }
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            SettingsIconTile(symbol: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Small square tile with an SF Symbol, used in every `SettingsSectionCard`
/// header. Same dimensions and corner radius across the screen so the
/// headers line up visually.
struct SettingsIconTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A toggle row: leading icon, title + subtitle stack, trailing switch.
/// Used inside `SettingsSectionCard` for binary preferences.
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    @Binding var isOn: Bool
    let accessibilityIdentifier: String?

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        isOn: Binding<Bool>,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self._isOn = isOn
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                SettingsIconTile(symbol: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

/// A segmented picker row: leading icon, title + subtitle stack, trailing
/// segmented control. The icon is decorative — the picker is the input.
struct SettingsSegmentedRow<Value: Hashable & Identifiable, Label: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let selection: Binding<Value>
    let options: [Value]
    let label: (Value) -> Label
    let accessibilityIdentifier: String?

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        selection: Binding<Value>,
        options: [Value],
        accessibilityIdentifier: String? = nil,
        @ViewBuilder label: @escaping (Value) -> Label
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.selection = selection
        self.options = options
        self.label = label
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                SettingsIconTile(symbol: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Picker("", selection: selection) {
                ForEach(options) { option in
                    label(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityIdentifier(accessibilityIdentifier ?? "")
        }
    }
}

/// A read-only "value" row: leading icon, label, trailing emphasised value.
/// Used to surface the current effective setting without offering to change
/// it (e.g. "Always required" for confirmation).
struct SettingsValueRow: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            SettingsIconTile(symbol: icon, tint: tint)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: AppTheme.Spacing.small)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A row that opens another screen (NavigationLink). Leading icon, title +
/// subtitle, trailing chevron. Visually similar to a Finder list row.
struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let destination: SettingsNavigationDestination
    let accessibilityIdentifier: String?

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color,
        destination: SettingsNavigationDestination,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.destination = destination
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        NavigationLink {
            destination.view
        } label: {
            HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
                SettingsIconTile(symbol: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: AppTheme.Spacing.small)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

/// Type-erased wrapper for the view a `SettingsNavigationRow` opens. Keeps
/// the row's call site free of generic noise and lets future rows open any
/// destination without changing the row's signature.
struct SettingsNavigationDestination {
    let view: AnyView
}
