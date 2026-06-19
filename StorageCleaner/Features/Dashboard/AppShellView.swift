import SwiftUI

struct AppShellView: View {
    @Bindable var viewModel: DashboardViewModel
    @State private var selection: SidebarItem? = .section(.overview)
    @State private var detailPath = NavigationPath()

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selection,
                isScanning: viewModel.isScanning
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            NavigationStack(path: $detailPath) {
                Group {
                    switch selection {
                    case .section(.overview), .none:
                        DashboardView(viewModel: viewModel)
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
                    case .section(.runtimeVersions):
                        RuntimeVersionsView(
                            onRemove: { urls in _ = await viewModel.removeCLIPrograms(urls) }
                        )
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
            .background {
                ZStack {
                    AppTheme.appBackground

                    LinearGradient(
                        colors: [
                            AppTheme.accent.opacity(0.045),
                            Color.clear,
                            AppTheme.violet.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
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
    }
}

// MARK: - Section view builders

extension AppShellView {
    private var section: AppSection? { selection?.section }

    private var detailNavigationID: String {
        "\(section?.rawValue ?? "none").\(viewModel.phase.navigationIdentity)"
    }

    @ViewBuilder
    private func developerStorageView() -> some View {
        let kinds = DeveloperDomains.kinds
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Developer Storage",
                subtitle: "Only developer storage locations are being scanned."
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            DeveloperStorageView(
                findings: viewModel.snapshot?.findings ?? [],
                onScan: {
                    resetDetailNavigation()
                    viewModel.startScan(for: kinds)
                },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                },
                onOpenFinding: openFinding
            )
        }
    }

    @ViewBuilder
    private func largeFilesView(kinds: [StorageFindingKind]) -> some View {
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Large Files",
                subtitle: "Only large-file locations are being scanned."
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            LargeFilesView(
                findings: filteredFindings(for: kinds),
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    private func leftoversView(kinds: [StorageFindingKind]) -> some View {
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Leftovers",
                subtitle: "Only leftover-installer locations are being scanned."
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            LeftoversView(
                findings: filteredFindings(for: kinds),
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    private func mediaCategoryView(
        title: String,
        kinds: [StorageFindingKind],
        emptyStateMessage: String
    ) -> some View {
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning \(title)",
                subtitle: "Only this category is being scanned."
            )
                .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            MediaCategoryView(
                title: title,
                findings: filteredFindings(for: kinds),
                emptyStateMessage: emptyStateMessage,
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    private func duplicatesView(kinds: [StorageFindingKind]) -> some View {
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning for Duplicates",
                subtitle: "Comparing media by content to find byte-identical copies."
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            DuplicatesView(
                findings: filteredFindings(for: kinds),
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    private func cliProgramsView(
        kinds: [StorageFindingKind],
        emptyStateMessage: String
    ) -> some View {
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning CLI Programs",
                subtitle: "Only command-line tool locations are being scanned."
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle, .results, .empty:
            CLIProgramsView(
                findings: filteredFindings(for: kinds),
                emptyStateMessage: emptyStateMessage,
                onScan: { viewModel.startScan(for: kinds) },
                onRemove: { urls in
                    _ = await viewModel.removeCLIPrograms(urls)
                }
            )
        }
    }

    private func filteredFindings(for kinds: [StorageFindingKind]) -> [StorageFinding] {
        guard !kinds.isEmpty else { return [] }
        return (viewModel.snapshot?.findings ?? []).filter { kinds.contains($0.kind) }
    }

    private func openFinding(_ finding: StorageFinding) {
        route(to: finding)
        viewModel.selectedFinding = finding
    }

    private func route(to finding: StorageFinding) {
        detailPath = NavigationPath()
        detailPath.append(finding)
    }

    private func resetDetailNavigation() {
        detailPath = NavigationPath()
        viewModel.selectedFinding = nil
    }

    @ViewBuilder
    private func findingDestination(for finding: StorageFinding) -> some View {
        if finding.kind == .duplicatePhotos
            || finding.kind == .duplicateVideos
            || finding.kind == .duplicateDocuments {
            DuplicatesView(
                findings: [finding],
                onScan: { viewModel.startScan(for: DuplicateMediaFilter.all.kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        } else if finding.kind == .dockerArtifacts {
            DockerView(onDockerChanged: {
                viewModel.startScan(for: [.dockerArtifacts])
            })
        } else if finding.kind == .cliApps {
            // Reuse the exact same CLI Programs view/discovery as the
            // sidebar, so tapping the Overview card shows identical results.
            CLIProgramsView(
                findings: [finding],
                emptyStateMessage: "Homebrew, version managers, global npm packages, "
                    + "and standalone CLI tools you've installed.",
                onScan: { viewModel.startScan(for: [.cliApps]) },
                onRemove: { urls in _ = await viewModel.removeCLIPrograms(urls) }
            )
        } else if finding.kind == .runtimeVersions {
            // Reuse the grouped Runtime Versions experience for the Overview card.
            RuntimeVersionsView(
                onRemove: { urls in _ = await viewModel.removeCLIPrograms(urls) }
            )
        } else if AppSection.leftovers.filterKinds.contains(finding.kind) {
            // Reuse the exact same Leftovers view as the sidebar, so tapping either the
            // installer or APK Overview card shows the unified results.
            LeftoversView(
                findings: filteredFindings(for: AppSection.leftovers.filterKinds),
                onScan: { viewModel.startScan(for: AppSection.leftovers.filterKinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        } else {
            CategoryDetailView(
                finding: finding,
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }
}

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
