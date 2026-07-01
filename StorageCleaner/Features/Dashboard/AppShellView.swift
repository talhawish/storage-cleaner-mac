import SwiftUI

struct AppShellView: View {
    @Bindable var viewModel: DashboardViewModel
    @Bindable var subscriptionController: SubscriptionController
    @State var selection: SidebarItem? = .section(.overview)
    @State var detailPath = NavigationPath()
    @State private var pendingSwitch: PendingSidebarSwitch?
    @State private var isSidebarExpanded = true
    @AppStorage("showReviewItems")
    var showReviewItems = true

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
        .sheet(item: paywallBinding) { trigger in
            PaywallSheet(
                controller: subscriptionController,
                trigger: trigger
            )
        }
    }
}

// MARK: - Layout

private extension AppShellView {
    @ViewBuilder var sidebarColumn: some View {
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
                            AppsView(
                                canUseProActions: viewModel.canCleanup,
                                onRequirePro: { _ = viewModel.gateFileAction() }
                            )
                        case .section(.projectActivity):
                            ProjectActivityView(
                                canUseProActions: viewModel.canCleanup,
                                onRequirePro: { _ = viewModel.gateFileAction() }
                            )
                        case .section(.developerStorage):
                            developerStorageView()
                        case .section(.docker):
                            DockerView(
                                canUseProActions: viewModel.canCleanup,
                                onRequirePro: { _ = viewModel.gateFileAction() },
                                onDockerChanged: {
                                    viewModel.startScan(for: [.dockerArtifacts])
                                }
                            )
                        case .section(.simulatorsEmulators):
                            EmulatorsView(
                                canUseProActions: viewModel.canCleanup,
                                onRequirePro: { _ = viewModel.gateFileAction() },
                                onCleanupComplete: { result, images in
                                    await viewModel.reconcileEmulatorCleanup(result, removedImages: images)
                                }
                            )
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
                            CleanupHistoryView(canRevealInFinder: viewModel.canCleanup)
                        case .section(.settings):
                            InAppSettingsView(subscriptionController: subscriptionController)
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

// MARK: - Paywall sheet

private extension AppShellView {
    /// Bridges the controller's `paywallRequest` (an optional
    /// `PaywallTrigger`) into the `Binding<PaywallTrigger?>`
    /// SwiftUI's `.sheet(item:)` needs. Setting it to `nil` from
    /// inside the sheet dismisses the sheet; the controller's
    /// `presentPaywall(_:)` writes a value to show it.
    var paywallBinding: Binding<PaywallTrigger?> {
        Binding(
            get: { subscriptionController.paywallRequest },
            set: { newValue in
                if newValue == nil {
                    subscriptionController.dismissPaywall()
                }
            }
        )
    }
}

/// The actual sheet. Creates a fresh `PaywallViewModel` per
/// presentation so the banner / spinner state never leaks between
/// sessions. The view model is stored in `@State` so it survives
/// parent re-renders — if it were recreated mid-flight the paywall
/// would snap back to skeleton state and never resolve.
private struct PaywallSheet: View {
    let controller: SubscriptionController
    let trigger: PaywallTrigger

    @Environment(\.openURL)
    private var openURL

    @State private var viewModel: PaywallViewModel

    init(controller: SubscriptionController, trigger: PaywallTrigger) {
        self.controller = controller
        self.trigger = trigger
        _viewModel = State(initialValue: PaywallViewModel(
            service: controller.service,
            onEntitlementUpgraded: { [weak controller] in
                controller?.dismissPaywall()
            }
        ))
    }

    var body: some View {
        PaywallView(
            viewModel: viewModel,
            onTermsTapped: { openURL(AppLinks.terms) },
            onPrivacyTapped: { openURL(AppLinks.privacy) }
        )
    }
}
