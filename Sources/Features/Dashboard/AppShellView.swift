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
                        LargeFilesView(
                            findings: viewModel.snapshot?.findings ?? [],
                            onDelete: { urls in
                                Task { await viewModel.deleteFiles(urls) }
                            }
                        )
                    case .cliPrograms:
                        MediaCategoryView(
                            title: "CLI Programs",
                            findings: filteredFindings(for: section?.filterKinds ?? []),
                            onDelete: { urls in
                                Task { await viewModel.deleteFiles(urls) }
                            }
                        )
                    case .screenshotsAndRecordings:
                        MediaCategoryView(
                            title: "Screenshots & Recordings",
                            findings: filteredFindings(for: section?.filterKinds ?? []),
                            onDelete: { urls in
                                Task { await viewModel.deleteFiles(urls) }
                            }
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

    private func filteredFindings(for kinds: [StorageFindingKind]) -> [StorageFinding] {
        guard !kinds.isEmpty else { return [] }
        return (viewModel.snapshot?.findings ?? []).filter { kinds.contains($0.kind) }
    }
}
