import SwiftUI

struct DockerView: View {
    private let onDockerChanged: () -> Void
    private let onCleanupComplete: (DockerCleanupEvent) async -> Void
    private let canUseProActions: Bool
    private let onRequirePro: () -> Void

    @State private var viewModel: DockerViewModel

    init(
        service: DockerService,
        canUseProActions: Bool = true,
        onRequirePro: @escaping () -> Void = {},
        onCleanupComplete: @escaping (DockerCleanupEvent) async -> Void = { _ in },
        onDockerChanged: @escaping () -> Void = {}
    ) {
        self.canUseProActions = canUseProActions
        self.onRequirePro = onRequirePro
        self.onCleanupComplete = onCleanupComplete
        self.onDockerChanged = onDockerChanged
        _viewModel = State(initialValue: DockerViewModel(service: service))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.snapshot == nil {
                loadingState
            } else if let snapshot = viewModel.snapshot {
                if !snapshot.isInstalled {
                    notInstalledState
                } else if !snapshot.daemonAvailable {
                    daemonUnavailableState(snapshot)
                } else {
                    content(snapshot)
                }
            } else {
                loadingState
            }
        }
        .navigationTitle("Docker")
        .navigationSubtitle(viewModel.subtitle)
        .accessibilityIdentifier("docker-root")
        .toolbar { toolbarContent }
        .onAppear(perform: viewModel.startLoading)
        .onDisappear(perform: viewModel.cancelLoading)
        .sheet(item: $viewModel.pendingAction) { action in
            DockerActionConfirmationSheet(
                action: action,
                onConfirm: {
                    viewModel.pendingAction = nil
                    perform(action)
                },
                onCancel: { viewModel.pendingAction = nil }
            )
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                viewModel.startLoading()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(viewModel.isLoading || viewModel.isPerformingAction)
            .help("Refresh Docker inventory")
        }
    }

    private func content(_ snapshot: DockerSnapshot) -> some View {
        VStack(spacing: 0) {
            header(snapshot)
            Divider()
            tabBar
            Divider()

            if !snapshot.warnings.isEmpty {
                DockerWarningBanner(warnings: snapshot.warnings)
            }

            if let result = viewModel.actionResult {
                DockerActionResultBanner(result: result)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    switch viewModel.selectedTab {
                    case .containers:
                        containerList(snapshot)
                    case .images:
                        imageList(snapshot)
                    case .volumes:
                        volumeList(snapshot)
                    case .buildCache:
                        buildCachePanel(snapshot.builderCache)
                    case .stats:
                        statsList(snapshot)
                    }
                }
                .padding(20)
            }
            .disabled(viewModel.isPerformingAction)
            .overlay {
                if viewModel.isPerformingAction {
                    ProgressView("Waiting for Docker…")
                        .padding(14)
                        .background(.regularMaterial, in: .rect(cornerRadius: AppTheme.Radius.small))
                }
            }
        }
    }

    private func header(_ snapshot: DockerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
                        .fill(AppTheme.violet.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Docker")
                        .font(.title2.weight(.semibold))
                    Text(snapshot.version.map { "Engine \($0)" } ?? snapshot.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(StorageFormatting.bytes(snapshot.totalBytes))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("used by Docker")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if snapshot.reclaimableBytes > 0 {
                        Text("\(StorageFormatting.bytes(snapshot.reclaimableBytes)) reclaimable")
                            .font(.caption)
                            .foregroundStyle(AppTheme.mint)
                    }
                }
            }

            metricsGrid(snapshot)
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private func metricsGrid(_ snapshot: DockerSnapshot) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            DockerMetricTile(
                title: "Images",
                value: "\(snapshot.images.count)",
                usedBytes: snapshot.diskUsage?.images.usedBytes ?? snapshot.imageBytes,
                reclaimableBytes: snapshot.diskUsage?.images.reclaimableBytes
            )
            DockerMetricTile(
                title: "Containers",
                value: "\(snapshot.containers.count)",
                usedBytes: snapshot.diskUsage?.containers.usedBytes ?? snapshot.containerBytes,
                reclaimableBytes: snapshot.diskUsage?.containers.reclaimableBytes
            )
            DockerMetricTile(
                title: "Volumes",
                value: "\(snapshot.volumes.count)",
                usedBytes: snapshot.diskUsage?.volumes.usedBytes ?? snapshot.volumeBytes,
                reclaimableBytes: snapshot.diskUsage?.volumes.reclaimableBytes
            )
            DockerMetricTile(
                title: "Build Cache",
                value: "\(snapshot.builderCache.entryCount)",
                usedBytes: snapshot.builderCache.bytes,
                reclaimableBytes: snapshot.builderCache.reclaimableBytes
            )
        }
    }

    private var tabBar: some View {
        Picker("Docker section", selection: $viewModel.selectedTab) {
            ForEach(DockerTab.allCases) { tab in
                Label(tab.title, systemImage: tab.symbolName).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func containerList(_ snapshot: DockerSnapshot) -> some View {
        let statsByID = Dictionary(snapshot.stats.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let statsByName = Dictionary(snapshot.stats.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        return Group {
            if snapshot.containers.isEmpty {
                emptyInlineState("No containers", systemImage: "shippingbox")
            } else {
                ForEach(snapshot.containers) { container in
                    DockerContainerRow(
                        container: container,
                        stats: statsByID[container.id] ?? statsByName[container.name],
                        onStop: { request(.stopContainer(container)) },
                        onRemove: { request(.removeContainer(container)) }
                    )
                }
            }
        }
    }

    private func imageList(_ snapshot: DockerSnapshot) -> some View {
        Group {
            if snapshot.images.isEmpty {
                emptyInlineState("No images", systemImage: "photo.stack")
            } else {
                ForEach(snapshot.images) { image in
                    DockerImageRow(
                        image: image,
                        onRemove: { request(.removeImage(image)) }
                    )
                }
            }
        }
    }

    private func volumeList(_ snapshot: DockerSnapshot) -> some View {
        Group {
            if snapshot.volumes.isEmpty {
                emptyInlineState("No volumes", systemImage: "externaldrive")
            } else {
                ForEach(snapshot.volumes) { volume in
                    DockerVolumeRow(
                        volume: volume,
                        onRemove: { request(.removeVolume(volume)) }
                    )
                }
            }
        }
    }

    private func buildCachePanel(_ cache: DockerBuilderCache) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.orange)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Builder Cache")
                        .font(.headline)
                    Text("\(cache.entryCount) entries - \(StorageFormatting.bytes(cache.bytes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    request(.pruneBuilderCache(cache))
                } label: {
                    Label("Prune", systemImage: "trash")
                }
                .disabled(cache.reclaimableBytes == 0)
            }

            Text(
                "Pruning removes reusable build layers. Docker can recreate them, "
                    + "but the next image build may take longer."
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardSurface()
    }

    private func statsList(_ snapshot: DockerSnapshot) -> some View {
        Group {
            if snapshot.stats.isEmpty {
                emptyInlineState("No running container stats", systemImage: "chart.line.uptrend.xyaxis")
            } else {
                ForEach(snapshot.stats) { stats in
                    DockerStatsRow(stats: stats)
                }
            }
        }
    }

    private func emptyInlineState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
            Text("Refresh after Docker creates new resources.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .cardSurface()
    }

    private var loadingState: some View {
        ScanningLoaderView(
            title: "Reading Docker inventory",
            subtitle: "Querying the Docker CLI for images, containers, volumes, and build cache.",
            progress: nil,
            scanners: [
                ScannerLoaderItem(
                    id: "docker-engine",
                    title: "Docker engine",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "docker version, docker info",
                    systemImage: "shippingbox.fill",
                    tint: AppTheme.violet
                ),
                ScannerLoaderItem(
                    id: "docker-inventory",
                    title: "Images & containers",
                    state: .pending,
                    itemsScanned: 0,
                    message: "docker images, docker ps -a",
                    systemImage: "list.bullet.rectangle",
                    tint: .secondary
                )
            ],
            cancelAction: viewModel.cancelLoading
        )
    }

    private var notInstalledState: some View {
        EmptyStateView(
            title: "Docker is not installed",
            message: "Install Docker Desktop or the Docker CLI to manage local images, "
                + "containers, volumes, and build cache.",
            systemImage: "shippingbox",
            tint: AppTheme.violet,
            actionTitle: "Refresh",
            action: viewModel.startLoading
        )
        .frame(minHeight: 430)
    }

    private func daemonUnavailableState(_ snapshot: DockerSnapshot) -> some View {
        EmptyStateView(
            title: "Docker is installed",
            message: snapshot.statusMessage,
            systemImage: "shippingbox.fill",
            tint: AppTheme.violet,
            actionTitle: "Refresh",
            action: viewModel.startLoading
        )
        .frame(minHeight: 430)
    }
}

// MARK: - Behaviour

private extension DockerView {
    func request(_ action: PendingDockerAction) {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        viewModel.pendingAction = action
    }

    func perform(_ action: PendingDockerAction) {
        Task {
            let outcome = await viewModel.perform(action)
            guard outcome.succeeded else { return }
            if let cleanup = outcome.cleanup {
                await onCleanupComplete(cleanup)
            }
            onDockerChanged()
        }
    }
}
