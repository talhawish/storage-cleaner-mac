import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var showQuickClean = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                    header

                    switch viewModel.phase {
                    case .idle:
                        WelcomeHeroView(startScan: viewModel.startScan)
                        quickCleanCard
                        TrustStripView()
                    case .scanning:
                        ScanProgressView(viewModel: viewModel)
                    case .results:
                        results(scrollProxy: proxy)
                    case .empty:
                        AnimatedEmptyState(
                            title: "Your developer storage is tidy",
                            message: "No re-creatable developer files were found in the selected locations.",
                            actionTitle: "Scan Again",
                            action: viewModel.startScan
                        )
                        .frame(minHeight: 430)
                    case .permissionRequired:
                        PermissionRequiredView(
                            blockedPermissions: viewModel.blockedPermissions,
                            onOpenSettings: viewModel.openSystemSettings,
                            onRetry: viewModel.retryAfterPermission
                        )
                    case let .failed(message):
                        ErrorStateView(message: message, retry: viewModel.startScan)
                    }
                }
                .padding(28)
                .animation(reduceMotion ? nil : .snappy(duration: 0.42), value: viewModel.phase)
            }
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.startScan()
                } label: {
                    Label(viewModel.isScanning ? "Scanning…" : "Scan Now", systemImage: "sparkle.magnifyingglass")
                }
                .accessibilityIdentifier("toolbar-scan-button")
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: [.command])
                .help("Start a new storage scan (⌘R)")
            }
        }
        .sheet(isPresented: $showQuickClean) {
            QuickCleanView(onClean: { urls in
                await viewModel.deleteFiles(urls)
            })
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(greeting)
                .font(.largeTitle.bold())
            Text("Understand what is using space before deciding what to clean.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Label(viewModel.permissionSummary, systemImage: "lock.shield")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var quickCleanCard: some View {
        Button {
            showQuickClean = true
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Clean")
                        .font(.headline)
                    Text("Scan and remove safe-to-delete files in one tap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(22)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.3), AppTheme.cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Quick Clean to scan and remove safe files")
    }

    @ViewBuilder
    private func results(scrollProxy: ScrollViewProxy) -> some View {
        if let snapshot = viewModel.snapshot {
            VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                OverviewSummaryBar(
                    snapshot: snapshot,
                    safeBytes: viewModel.safeReclaimableBytes,
                    reviewBytes: viewModel.reviewReclaimableBytes,
                    startScan: viewModel.startScan,
                    quickClean: { showQuickClean = true }
                )

                if !viewModel.domainTiles.isEmpty {
                    SpaceBreakdownGrid(tiles: viewModel.domainTiles) { domain in
                        withAnimation(reduceMotion ? nil : .snappy) {
                            scrollProxy.scrollTo(domain, anchor: .top)
                        }
                    }
                }

                OverviewTipsCarousel(tips: viewModel.overviewTips, onAction: handleTip)

                VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                    ForEach(viewModel.domainGroups) { usage in
                        DetectionGroupSection(usage: usage) { viewModel.selectedFinding = $0 }
                            .id(usage.domain)
                    }
                }
            }
            .accessibilityIdentifier("dashboard-results")
        }
    }

    private func handleTip(_ tip: OverviewTip) {
        switch tip.action {
        case .quickClean:
            showQuickClean = true
        case let .reveal(kind):
            viewModel.selectedFinding = viewModel.finding(for: kind)
        case .none:
            break
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
