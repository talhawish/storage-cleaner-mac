import SwiftUI

struct AppsView: View {
    @State private var apps: [AppItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var appToDelete: AppItem?
    @State private var loadTask: Task<Void, Never>?
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
        .accessibilityIdentifier("applications-root")
        .toolbar {
            toolbarContent
        }
        .onAppear { startLoadingApps() }
        .onDisappear { cancelLoadingApps() }
        .sheet(item: $appToDelete) { app in
            DeleteAppConfirmationSheet(
                app: app,
                onUninstall: {
                    try await uninstallApp(app)
                },
                onCancel: { appToDelete = nil }
            )
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .accessibilityHidden(true)
            }
            .help("Sort apps")
            .accessibilityLabel("Sort apps")
        }

        ToolbarItem {
            Button {
                startLoadingApps()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .accessibilityHidden(true)
            }
            .help("Rescan applications")
            .accessibilityLabel("Rescan applications")
        }
    }

    private var loadingView: some View {
        ScanningLoaderView(
            title: "Scanning applications",
            subtitle: "Reading /Applications and ~/Applications to inventory every installed app and its size.",
            progress: nil,
            scanners: [
                ScannerLoaderItem(
                    id: "system-applications",
                    title: "System Applications",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "/Applications",
                    systemImage: "macwindow.on.rectangle",
                    tint: AppTheme.accent
                ),
                ScannerLoaderItem(
                    id: "user-applications",
                    title: "User Applications",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "~/Applications",
                    systemImage: "person.fill",
                    tint: AppTheme.violet
                )
            ],
            cancelAction: cancelLoadingApps
        )
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No Applications",
            message: "No applications were found in /Applications or ~/Applications.",
            systemImage: "app.badge",
            tint: AppTheme.accent
        )
    }

    private var appList: some View {
        VStack(spacing: 0) {
            SearchField(text: $searchText, prompt: "Search apps…")
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            statsBar

            List {
                Section {
                    ForEach(filteredApps) { app in
                        AppRowView(
                            app: app,
                            onReveal: { Task { await inventoryService.revealInFinder(app) } },
                            onUninstall: { appToDelete = app }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            Text("Total: \(StorageFormatting.bytes(totalSize))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(filteredApps.count) of \(apps.count) apps")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func loadApps() async {
        isLoading = true
        let found = await inventoryService.scanInstalledApps()
        guard !Task.isCancelled else { return }
        apps = found
        isLoading = false
        loadTask = nil
    }

    private func startLoadingApps() {
        loadTask?.cancel()
        loadTask = Task { await loadApps() }
    }

    private func cancelLoadingApps() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    private func uninstallApp(_ app: AppItem) async throws {
        try await inventoryService.uninstallApp(app)
        apps.removeAll { $0.id == app.id }
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
