import SwiftUI

struct AppShellView: View {
    @Bindable var viewModel: DashboardViewModel
    @State private var selection: AppSection? = .overview
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selection,
                showSettings: $showSettings,
                isScanning: viewModel.isScanning
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            NavigationStack {
                Group {
                    switch selection {
                    case .overview, .none:
                        DashboardView(viewModel: viewModel)
                    case .apps:
                        AppsView()
                    case .projectActivity:
                        ProjectActivityView()
                    case .developerStorage:
                        DeveloperStorageView(
                            findings: viewModel.snapshot?.findings ?? [],
                            onDelete: { urls in
                                Task { await viewModel.deleteFiles(urls) }
                            }
                        )
                    case .largeFiles:
                        largeFilesView(
                            kinds: section?.filterKinds ?? []
                        )
                    case .cliPrograms:
                        mediaCategoryView(
                            title: "CLI Programs",
                            kinds: section?.filterKinds ?? [],
                            emptyStateMessage: "Run a scan to find Homebrew caches, version managers, "
                                + "and installed CLI toolchains."
                        )
                    case .screenshotsAndRecordings:
                        mediaCategoryView(
                            title: "Screenshots & Recordings",
                            kinds: section?.filterKinds ?? [],
                            emptyStateMessage: "Run a scan to find screenshots and screen recordings "
                                + "in common media locations."
                        )
                    case .duplicates:
                        DuplicatesView(
                            findings: viewModel.snapshot?.findings ?? [],
                            onDelete: { urls in
                                Task { await viewModel.deleteFiles(urls) }
                            }
                        )
                    case .cleanupHistory:
                        CleanupHistoryView()
                    }
                }
                .navigationDestination(item: $viewModel.selectedFinding) { finding in
                    CategoryDetailView(
                        finding: finding,
                        onDelete: { urls in
                            Task { await viewModel.deleteFiles(urls) }
                        }
                    )
                }
            }
            .background {
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.055),
                        Color.clear,
                        AppTheme.violet.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
        .sheet(isPresented: $showSettings) {
            InAppSettingsView()
        }
    }

    private var section: AppSection? { selection }

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

    private func filteredFindings(for kinds: [StorageFindingKind]) -> [StorageFinding] {
        guard !kinds.isEmpty else { return [] }
        return (viewModel.snapshot?.findings ?? []).filter { kinds.contains($0.kind) }
    }
}
