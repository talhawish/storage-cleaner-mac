import SwiftUI

struct AppsView: View {
    @State private var apps: [AppItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var selectedApps: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var appToDelete: AppItem?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let inventoryService = AppInventoryService()

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Largest First"
        case sizeAsc = "Smallest First"
        case nameAsc = "Name A–Z"
        case nameDesc = "Name Z–A"
    }

    private var filteredApps: [AppItem] {
        let list = apps
        let searched: [AppItem]
        if searchText.isEmpty {
            searched = list
        } else {
            searched = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
            }
        }
        return sortedApps(from: searched)
    }

    private var totalSize: Int64 {
        apps.reduce(0) { $0 + $1.sizeBytes }
    }

    private var selectedTotalSize: Int64 {
        apps.filter { selectedApps.contains($0.bundleIdentifier) }
            .reduce(0) { $0 + $1.sizeBytes }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if apps.isEmpty {
                emptyState
            } else {
                appList
            }
        }
        .navigationTitle("Applications")
        .navigationSubtitle("\(apps.count) apps installed")
        .toolbar {
            toolbarContent
        }
        .task {
            await loadApps()
        }
        .sheet(item: $appToDelete) { app in
            DeleteAppConfirmationSheet(
                app: app,
                onDelete: {
                    await uninstallApp(app)
                },
                onCancel: { appToDelete = nil }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .help("Sort apps")
        }

        ToolbarItem {
            Button {
                Task { await loadApps() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Rescan applications")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning applications…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Applications", systemImage: "app.badge")
        } description: {
            Text("No applications were found in /Applications or ~/Applications.")
        }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            searchBar

            statsBar

            List {
                Section {
                    ForEach(filteredApps) { app in
                        AppRowView(
                            app: app,
                            isSelected: selectedApps.contains(app.bundleIdentifier),
                            onToggle: { toggleApp(app) },
                            onReveal: { Task { await inventoryService.revealInFinder(app) } },
                            onDelete: { appToDelete = app }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField("Search apps…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            if !selectedApps.isEmpty {
                Button {
                    selectedApps.removeAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Clear selection")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 16)

                Text("\(selectedApps.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)

                Text(StorageFormatting.bytes(selectedTotalSize))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("Total: \(StorageFormatting.bytes(totalSize))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(filteredApps.count) of \(apps.count) apps")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func toggleApp(_ app: AppItem) {
        if selectedApps.contains(app.bundleIdentifier) {
            selectedApps.remove(app.bundleIdentifier)
        } else {
            selectedApps.insert(app.bundleIdentifier)
        }
    }

    private func loadApps() async {
        isLoading = true
        let found = await inventoryService.scanInstalledApps()
        apps = found
        isLoading = false
    }

    private func uninstallApp(_ app: AppItem) async {
        try? await inventoryService.uninstallApp(app)
        apps.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        selectedApps.remove(app.bundleIdentifier)
    }

    private func sortedApps(from list: [AppItem]) -> [AppItem] {
        switch sortOption {
        case .sizeDesc: list.sorted { $0.sizeBytes > $1.sizeBytes }
        case .sizeAsc: list.sorted { $0.sizeBytes < $1.sizeBytes }
        case .nameAsc: list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc: list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
    }
}
