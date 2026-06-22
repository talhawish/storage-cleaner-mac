import SwiftUI

struct AppShellView: View {
    @Bindable var viewModel: DashboardViewModel
    @State var selection: SidebarItem? = .section(.overview)
    @State var detailPath = NavigationPath()
    @State private var pendingSwitch: PendingSidebarSwitch?
    @State private var isSidebarExpanded = true

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn

            Divider()

            detailColumn
        }
        .animation(.smooth, value: isSidebarExpanded)
        .tint(AppTheme.accent)
        .navigationTitle("Storage Cleaner")
        .toolbar { sidebarToggleToolbarItem }
        .onChange(of: selection) { _, _ in
            resetDetailNavigation()
        }
        .onChange(of: viewModel.selectedFinding) { _, finding in
            guard let finding else {
                detailPath = NavigationPath()
                return
            }
            route(to: finding)
        }
        .onChange(of: viewModel.phase.navigationIdentity) { oldValue, newValue in
            if oldValue == "scanning", newValue != "scanning" {
                resetDetailNavigation()
            }
        }
        .sheet(item: $pendingSwitch) { pending in
            StopScanConfirmationSheet(
                originSection: pending.originTitle,
                destinationSection: pending.destinationTitle,
                onConfirm: {
                    if viewModel.isScanning {
                        viewModel.cancelScan()
                    }
                    selection = pending.destination
                    pendingSwitch = nil
                },
                onCancel: { pendingSwitch = nil }
            )
        }
    }
}

// MARK: - Layout

private extension AppShellView {
    @ViewBuilder
    var sidebarColumn: some View {
        if isSidebarExpanded {
            SidebarView(
                selection: selectionBinding,
                isScanning: viewModel.isScanning
            )
            .frame(width: 240)
        } else {
            MiniSidebarView(
                selection: selectionBinding,
                isScanning: viewModel.isScanning
            )
        }
    }

    var detailColumn: some View {
        AppTheme.appBackground
            .ignoresSafeArea()
            .overlay {
                NavigationStack(path: $detailPath) {
                    Group {
                        switch selection {
                        case .section(.overview), .none:
                            DashboardView(
                                viewModel: viewModel,
                                onOpenSettings: { selection = .section(.settings) }
                            )
                        case .section(.apps):
                            AppsView()
                        case .section(.projectActivity):
                            ProjectActivityView()
                        case .section(.developerStorage):
                            developerStorageView()
                        case .section(.docker):
                            DockerView(onDockerChanged: {
                                viewModel.startScan(for: [.dockerArtifacts])
                            })
                        case .section(.simulatorsEmulators):
                            EmulatorsView()
                        case .section(.largeFiles):
                            largeFilesView(
                                kinds: section?.filterKinds ?? []
                            )
                        case .section(.cliPrograms):
                            cliProgramsView(
                                kinds: section?.filterKinds ?? [],
                                emptyStateMessage: "Run a scan to find Homebrew caches, version managers, "
                                    + "and installed CLI toolchains."
                            )
                        case .section(.screenshotsAndRecordings):
                            mediaCategoryView(
                                title: "Screenshots & Recordings",
                                kinds: section?.filterKinds ?? [],
                                emptyStateMessage: "Run a scan to find screenshots and screen recordings "
                                    + "in common media locations."
                            )
                        case .section(.duplicates):
                            duplicatesView(kinds: DuplicateMediaFilter.all.kinds)
                        case .section(.leftovers):
                            leftoversView(kinds: section?.filterKinds ?? [])
                        case .section(.systemJunk):
                            systemJunkView(kinds: section?.filterKinds ?? [])
                        case .section(.cleanupHistory):
                            CleanupHistoryView()
                        case .section(.settings):
                            InAppSettingsView()
                        }
                    }
                    .navigationDestination(for: StorageFinding.self) { finding in
                        findingDestination(for: finding)
                    }
                }
                .id(detailNavigationID)
            }
    }

    var sidebarToggleToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                isSidebarExpanded.toggle()
            } label: {
                Image(systemName: isSidebarExpanded ? "sidebar.left" : "sidebar.right")
            }
            .help(isSidebarExpanded ? "Collapse sidebar" : "Expand sidebar")
            .accessibilityIdentifier("toolbar-sidebar-toggle")
        }
    }
}

// MARK: - Selection binding

extension AppShellView {
    /// Selection binding that intercepts changes when a scan is in progress.
    /// Same-section clicks pass through; any other click while scanning
    /// routes to a confirmation sheet instead of switching directly.
    fileprivate var selectionBinding: Binding<SidebarItem?> {
        Binding(
            get: { selection },
            set: { newValue in
                guard let newValue else {
                    selection = newValue
                    return
                }
                if !viewModel.isScanning || newValue == selection {
                    selection = newValue
                    return
                }
                pendingSwitch = PendingSidebarSwitch(
                    origin: selection,
                    destination: newValue
                )
            }
        )
    }

    fileprivate var section: AppSection? { selection?.section }

    fileprivate var detailNavigationID: String {
        "\(section?.rawValue ?? "none").\(viewModel.phase.navigationIdentity)"
    }
}

/// Intermediate state for a sidebar switch that needs user confirmation
/// because a scan is currently running.
private struct PendingSidebarSwitch: Identifiable {
    let origin: SidebarItem?
    let destination: SidebarItem
    var id: String { destination.id }

    var originTitle: String { origin?.section.title ?? "Overview" }
    var destinationTitle: String { destination.section.title }
}

// MARK: - ScanPhase identity

private extension ScanPhase {
    var navigationIdentity: String {
        switch self {
        case .idle: "idle"
        case .scanning: "scanning"
        case .results: "results"
        case .empty: "empty"
        case .permissionRequired: "permissionRequired"
        case .failed: "failed"
        }
    }
}
