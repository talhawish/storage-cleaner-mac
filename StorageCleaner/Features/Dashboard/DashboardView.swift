import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    var onOpenSettings: (() -> Void)?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @AppStorage("showReviewItems")
    private var showReviewItems = true
    @State private var showQuickClean = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                    header

                    StorageStatusCard(
                        volume: viewModel.volumeSnapshot,
                        totalReclaimableBytes: viewModel.totalReclaimableBytes,
                        title: statusTitle
                    )

                    switch viewModel.phase {
                    case .idle:
                        WelcomeHeroView(startScan: viewModel.startScan)
                        QuickCleanEntry(action: { showQuickClean = true })
                    case .scanning:
                        ScanProgressView(viewModel: viewModel)
                    case .results:
                        results(scrollProxy: proxy)
                    case .empty:
                        EmptyStateView(
                            title: "Your developer storage is tidy",
                            message: "No re-creatable developer files were found in the selected locations.",
                            systemImage: "checkmark.seal.fill",
                            tint: AppTheme.mint,
                            actionTitle: "Scan Again",
                            action: viewModel.startScan
                        )
                        .frame(minHeight: 430)
                    case .permissionRequired:
                        PermissionRequiredView(
                            blockedPermissions: viewModel.blockedPermissions,
                            onOpenSettings: viewModel.openSystemSettings,
                            onGrantAccess: viewModel.grantHomeFolderAccess
                        )
                    case let .failed(message):
                        ErrorStateView(message: message, retry: viewModel.startScan)
                    }
                }
                .padding(20)
                .animation(reduceMotion ? nil : .snappy(duration: 0.42), value: viewModel.phase)
            }
            .onAppear { viewModel.refreshVolumeSnapshot() }
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.startScan()
                } label: {
                    Label(viewModel.isScanning ? "Scanning…" : "Scan Now", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("toolbar-scan-button")
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: [.command])
                .help("Start a new storage scan (⌘R)")
            }
        }
        .sheet(isPresented: $showQuickClean) {
            QuickCleanView(
                viewModel: QuickCleanViewModel.make(
                    permissionHandler: viewModel.permissionHandler,
                    onClean: { urls in
                        await viewModel.deleteFiles(urls)
                    },
                    volumeProvider: {
                        viewModel.refreshVolumeSnapshot()
                        return viewModel.volumeSnapshot.isAvailable
                            ? viewModel.volumeSnapshot.freeBytes
                            : nil
                    }
                ),
                onOpenSettings: {
                    showQuickClean = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenSettings?()
                    }
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title.weight(.semibold))
            if let permissionBanner {
                Label(permissionBanner, systemImage: permissionBannerIcon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(permissionBannerTint)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Permission banner copy. `nil` when every required scope is already
    /// accessible — the banner only renders when there is something to act on,
    /// so a healthy state stays quiet instead of repeating "Home Folder access
    /// ready" on every visit.
    private var permissionBanner: String? {
        if viewModel.phase == .permissionRequired { return nil }
        guard viewModel.hasPermissionIssues || !viewModel.warningPermissions.isEmpty else { return nil }
        return viewModel.permissionSummary
    }

    private var permissionBannerIcon: String {
        viewModel.hasPermissionIssues ? "lock.shield.fill" : "exclamationmark.shield"
    }

    private var permissionBannerTint: Color {
        viewModel.hasPermissionIssues ? AppTheme.orange : AppTheme.orange
    }

    private var statusTitle: String {
        switch viewModel.phase {
        case .scanning: "Storage · Scanning…"
        case .results: "Storage · After Cleanup"
        default: "Storage"
        }
    }

    @ViewBuilder
    private func results(scrollProxy: ScrollViewProxy) -> some View {
        if let snapshot = visibleSnapshot {
            VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                OverviewSummaryBar(
                    snapshot: snapshot,
                    safeBytes: StorageOverview.safeBytes(in: snapshot.findings),
                    reviewBytes: StorageOverview.reviewBytes(in: snapshot.findings),
                    startScan: viewModel.startScan,
                    quickClean: { showQuickClean = true }
                )

                let domainTiles = StorageOverview.tiles(in: snapshot.findings, maxTiles: 6)
                if !domainTiles.isEmpty {
                    SpaceBreakdownGrid(tiles: domainTiles) { domain in
                        withAnimation(reduceMotion ? nil : .snappy) {
                            scrollProxy.scrollTo(domain, anchor: .top)
                        }
                    }
                }

                OverviewTipsCarousel(tips: overviewTips(for: snapshot), onAction: handleTip)

                VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                    ForEach(StorageOverview.domainUsages(in: snapshot.findings)) { usage in
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
            viewModel.selectedFinding = visibleSnapshot?.findings.first { $0.kind == kind }
        case .none:
            break
        }
    }

    private var visibleSnapshot: ScanSnapshot? {
        guard let snapshot = viewModel.snapshot else { return nil }
        guard !showReviewItems else { return snapshot }
        return ScanSnapshot(
            findings: snapshot.findings.filter { $0.safety == .safe },
            scannedItemCount: snapshot.scannedItemCount,
            duration: snapshot.duration
        )
    }

    private func overviewTips(for snapshot: ScanSnapshot) -> [OverviewTip] {
        let visibleKinds = Set(snapshot.findings.map(\.kind))
        let visibleStaleHints = viewModel.staleHints.filter { visibleKinds.contains($0.kind) }
        return OverviewTipBuilder.tips(for: snapshot, stale: visibleStaleHints)
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
