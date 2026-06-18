import SwiftUI

struct SafeToDeleteView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("enabledCleanupOptions")
    private var enabledOptionsData = ""
    @State private var enabledOptions: Set<String> = []
    @State private var showResetConfirmation = false

    private var allOptions: [CleanupOption] {
        CleanupOptionsRegistry.allOptions
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                ForEach(CleanupOptionsRegistry.categories, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(28)
        }
        .navigationTitle("Safe to Delete")
        .onAppear { loadEnabled() }
        .onChange(of: enabledOptions) { saveEnabled() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .automatic) {
                Button("Reset to Defaults") {
                    showResetConfirmation = true
                }
                .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("Reset to defaults?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                enabledOptions = CleanupOptionsRegistry.safeByDefaultIDs
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore the default selection of safe-to-delete items.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Safe to Delete")
                .font(.largeTitle.bold())
            Text("Choose which categories are included in Quick Clean. Items marked as safe can be removed without risk.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                let safeCount = enabledOptions.filter { id in
                    CleanupOptionsRegistry.option(byID: id)?.safety == .safe
                }.count
                Label("\(safeCount) safe items enabled", systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.mint)
            }
            .padding(.top, 4)
        }
    }

    private func categorySection(_ category: CleanupOption.Category) -> some View {
        let options = CleanupOptionsRegistry.options(for: category)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: iconForCategory(category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colorForCategory(category))
                Text(category.rawValue)
                    .font(.headline)
            }

            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    optionRow(option)
                    if index < options.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
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

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(option.name)
                        .font(.body.weight(.medium))
                    StatusBadge(safety: option.safety)
                }
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
        switch name {
        case "blue": AppTheme.accent
        case "cyan": AppTheme.cyan
        case "mint": AppTheme.mint
        case "orange": AppTheme.orange
        case "pink": AppTheme.pink
        case "rose": AppTheme.rose
        case "indigo": AppTheme.indigo
        case "teal": AppTheme.teal
        case "violet": AppTheme.violet
        case "yellow": .yellow
        case "red": .red
        case "green": .green
        case "gray": .gray
        default: .secondary
        }
    }
}
