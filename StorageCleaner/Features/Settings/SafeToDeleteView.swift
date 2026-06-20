import SwiftUI

/// "Safe to Delete" settings screen. Lists every `CleanupOption` grouped by
/// category, with a search field, per-category "Enable all" toggle, and a
/// safety summary at the top so the user can see at a glance how many
/// safe-only vs review-required options are enabled.
///
/// The screen intentionally distinguishes safe-to-clean options (recoverable
/// data, safe to remove without review) from review-first options
/// (user-created content or toolchains that the user might still need).
struct SafeToDeleteView: View {
    @AppStorage("enabledCleanupOptions")
    private var enabledOptionsData = ""
    @State private var enabledOptions: Set<String> = []
    @State private var showResetConfirmation = false
    @State private var searchText = ""

    private let optionColorPalette: [String: Color] = [
        "blue": AppTheme.accent,
        "cyan": AppTheme.cyan,
        "mint": AppTheme.mint,
        "orange": AppTheme.orange,
        "pink": AppTheme.pink,
        "rose": AppTheme.rose,
        "indigo": AppTheme.indigo,
        "teal": AppTheme.teal,
        "violet": AppTheme.violet,
        "yellow": .yellow,
        "red": .red,
        "green": .green,
        "gray": .gray,
        "purple": AppTheme.violet
    ]

    private var allOptions: [CleanupOption] {
        CleanupOptionsRegistry.allOptions
    }

    private var visibleOptions: [CleanupOption] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allOptions }
        return allOptions.filter { option in
            option.name.lowercased().contains(query)
                || option.description.lowercased().contains(query)
        }
    }

    private var safeCount: Int {
        enabledOptions.filter { id in
            CleanupOptionsRegistry.option(byID: id)?.safety == .safe
        }.count
    }

    private var reviewCount: Int {
        enabledOptions.filter { id in
            CleanupOptionsRegistry.option(byID: id)?.safety == .review
        }.count
    }

    private var groupedByCategory: [(CleanupOption.Category, [CleanupOption])] {
        let categories = CleanupOptionsRegistry.categories
        return categories.compactMap { category in
            let options = visibleOptions.filter { $0.category == category }
            return options.isEmpty ? nil : (category, options)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                safetySummary
                searchField
                if groupedByCategory.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedByCategory, id: \.0) { category, options in
                        categorySection(category: category, options: options)
                    }
                }
            }
            .padding(28)
        }
        .background(AppTheme.appBackground)
        .navigationTitle("Safe to Delete")
        .onAppear { loadEnabled() }
        .onChange(of: enabledOptions) { saveEnabled() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showResetConfirmation) {
            ConfirmationModal(
                variant: .warning,
                title: "Reset to defaults?",
                message: "This will restore the default selection of safe-to-delete items.",
                iconSystemName: "arrow.uturn.backward.circle.fill",
                iconTint: AppTheme.orange,
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Reset",
                    systemImage: "arrow.uturn.backward",
                    isProminent: true,
                    isDefault: true,
                    action: {
                        enabledOptions = CleanupOptionsRegistry.safeByDefaultIDs
                    }
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Safe to Delete")
                .font(.largeTitle.bold())
            Text(
                "Choose which categories are included in Quick Clean. "
                    + "Items marked as safe can be removed without risk. "
                    + "Items marked as review may include user-created files."
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Safety summary

    private var safetySummary: some View {
        HStack(spacing: 14) {
            summaryCard(
                title: "Safe",
                count: safeCount,
                tint: AppTheme.mint,
                systemImage: "checkmark.shield.fill",
                subtitle: "Recoverable caches & build outputs"
            )
            summaryCard(
                title: "Review",
                count: reviewCount,
                tint: AppTheme.orange,
                systemImage: "eye.fill",
                subtitle: "May include user-created content"
            )
        }
    }

    private func summaryCard(
        title: String,
        count: Int,
        tint: Color,
        systemImage: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) \(title) enabled")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .cardSurface()
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Filter categories…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No matching categories")
                .font(.headline)
            Text("Try a different search term or clear the filter to see all categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Category section

    private func categorySection(category: CleanupOption.Category, options: [CleanupOption]) -> some View {
        let enabledInCategory = options.filter { enabledOptions.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: iconForCategory(category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorForCategory(category))
                    .frame(width: 28, height: 28)
                    .background(colorForCategory(category).opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)

                Text(category.rawValue)
                    .font(.headline)

                Spacer()

                Text("\(enabledInCategory) of \(options.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Button(allInCategoryEnabled(options) ? "Disable all" : "Enable all") {
                    toggleAllInCategory(options)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    optionRow(option)
                    if index < options.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
        }
    }

    private func optionRow(_ option: CleanupOption) -> some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { enabledOptions.contains(option.id) },
                set: { _ in toggleOption(option.id) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .accessibilityLabel("Enable \(option.name)")

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorForString(option.iconColor).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(colorForString(option.iconColor))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(option.name)
                        .font(.body.weight(.medium))
                    StatusBadge(safety: option.safety)
                    if option.isSafeByDefault {
                        Text("Default")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    }
                }
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Mutations

    private func allInCategoryEnabled(_ options: [CleanupOption]) -> Bool {
        options.allSatisfy { enabledOptions.contains($0.id) }
    }

    private func toggleAllInCategory(_ options: [CleanupOption]) {
        if allInCategoryEnabled(options) {
            options.forEach { enabledOptions.remove($0.id) }
        } else {
            options.forEach { enabledOptions.insert($0.id) }
        }
    }

    private func toggleOption(_ id: String) {
        if enabledOptions.contains(id) {
            enabledOptions.remove(id)
        } else {
            enabledOptions.insert(id)
        }
    }

    private func loadEnabled() {
        if enabledOptionsData.isEmpty {
            enabledOptions = CleanupOptionsRegistry.safeByDefaultIDs
        } else {
            enabledOptions = Set(enabledOptionsData.components(separatedBy: ","))
        }
    }

    private func saveEnabled() {
        enabledOptionsData = enabledOptions.sorted().joined(separator: ",")
    }

    // MARK: - Styling

    private func iconForCategory(_ category: CleanupOption.Category) -> String {
        switch category {
        case .developerTools: "chevron.left.forwardslash.chevron.right"
        case .caches: "archivebox.fill"
        case .media: "photo.on.rectangle.angled"
        case .system: "gearshape.fill"
        case .emulators: "apps.iphone"
        }
    }

    private func colorForCategory(_ category: CleanupOption.Category) -> Color {
        switch category {
        case .developerTools: AppTheme.accent
        case .caches: AppTheme.orange
        case .media: AppTheme.pink
        case .system: .secondary
        case .emulators: AppTheme.mint
        }
    }

    private func colorForString(_ name: String) -> Color {
        optionColorPalette[name, default: .secondary]
    }
}
