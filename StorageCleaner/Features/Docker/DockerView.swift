import SwiftUI

struct DockerView: View {
    private let service: DockerService
    private let onDockerChanged: () -> Void
    private let canUseProActions: Bool
    private let onRequirePro: () -> Void

    @State private var snapshot: DockerSnapshot?
    @State private var isLoading = true
    @State private var selectedTab: DockerTab = .containers
    @State private var pendingAction: PendingDockerAction?
    @State private var actionMessage: String?
    @State private var loadTask: Task<Void, Never>?

    init(
        service: DockerService = .live,
        canUseProActions: Bool = true,
        onRequirePro: @escaping () -> Void = {},
        onDockerChanged: @escaping () -> Void = {}
    ) {
        self.service = service
        self.canUseProActions = canUseProActions
        self.onRequirePro = onRequirePro
        self.onDockerChanged = onDockerChanged
    }

    var body: some View {
        Group {
            if isLoading && snapshot == nil {
                loadingState
            } else if let snapshot {
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
        .navigationSubtitle(subtitle)
        .toolbar { toolbarContent }
        .onAppear { startLoading() }
        .onDisappear { cancelLoading() }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                primaryButton: .destructive(Text(action.confirmTitle)) {
                    Task { await perform(action) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var subtitle: String {
        guard let snapshot else { return "Checking Docker" }
        if !snapshot.isInstalled { return "Not installed" }
        if !snapshot.daemonAvailable { return "Installed, daemon unavailable" }
        return "\(snapshot.containers.count) containers - \(snapshot.images.count) images - "
            + StorageFormatting.bytes(snapshot.totalBytes)
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                startLoading()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(isLoading)
            .help("Refresh Docker inventory")
        }
    }

    private func content(_ snapshot: DockerSnapshot) -> some View {
        VStack(spacing: 0) {
            header(snapshot)
            Divider()
            tabBar
            Divider()

            if let actionMessage {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityHidden(true)
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 9)
                .background(.regularMaterial)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    switch selectedTab {
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
        }
    }

    private func header(_ snapshot: DockerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                    Text("tracked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                detail: StorageFormatting.bytes(snapshot.imageBytes)
            )
            DockerMetricTile(
                title: "Containers",
                value: "\(snapshot.containers.count)",
                detail: StorageFormatting.bytes(snapshot.containerBytes)
            )
            DockerMetricTile(
                title: "Volumes",
                value: "\(snapshot.volumes.count)",
                detail: StorageFormatting.bytes(snapshot.volumeBytes)
            )
            DockerMetricTile(
                title: "Build Cache",
                value: "\(snapshot.builderCache.entryCount)",
                detail: StorageFormatting.bytes(snapshot.builderCache.bytes)
            )
        }
    }

    private var tabBar: some View {
        Picker("Docker section", selection: $selectedTab) {
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
                        onStop: { request(.stopContainer(id: container.id, name: container.name)) },
                        onRemove: { request(.removeContainer(id: container.id, name: container.name)) }
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
                        onRemove: { request(.removeImage(id: image.id, name: image.displayName)) }
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
                        onRemove: { request(.removeVolume(name: volume.name)) }
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
                    request(.pruneBuilderCache)
                } label: {
                    Label("Prune", systemImage: "trash")
                }
                .disabled(cache.bytes == 0)
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
            cancelAction: cancelLoading
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
            action: startLoading
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
            action: startLoading
        )
        .frame(minHeight: 430)
    }
}

// MARK: - Behaviour

private extension DockerView {
    func load() async {
        isLoading = true
        let nextSnapshot = await service.loadSnapshot()
        guard !Task.isCancelled else { return }
        snapshot = nextSnapshot
        isLoading = false
        loadTask = nil
    }

    func startLoading() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func request(_ action: PendingDockerAction) {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        pendingAction = action
    }

    func perform(_ action: PendingDockerAction) async {
        actionMessage = nil
        let result: DockerActionResult
        switch action {
        case let .stopContainer(id, _):
            result = await service.stopContainer(id: id)
        case let .removeContainer(id, _):
            result = await service.removeContainer(id: id)
        case let .removeImage(id, _):
            result = await service.removeImage(id: id)
        case let .removeVolume(name):
            result = await service.removeVolume(name: name)
        case .pruneBuilderCache:
            result = await service.pruneBuilderCache()
        }

        actionMessage = result.message
        if result.succeeded {
            await load()
            onDockerChanged()
        }
    }
}

private enum DockerTab: String, CaseIterable, Identifiable {
    case containers
    case images
    case volumes
    case buildCache
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .containers: "Containers"
        case .images: "Images"
        case .volumes: "Volumes"
        case .buildCache: "Build Cache"
        case .stats: "Stats"
        }
    }

    var symbolName: String {
        switch self {
        case .containers: "shippingbox"
        case .images: "photo.stack"
        case .volumes: "externaldrive"
        case .buildCache: "hammer"
        case .stats: "chart.line.uptrend.xyaxis"
        }
    }
}

private enum PendingDockerAction: Identifiable {
    case stopContainer(id: String, name: String)
    case removeContainer(id: String, name: String)
    case removeImage(id: String, name: String)
    case removeVolume(name: String)
    case pruneBuilderCache

    var id: String {
        switch self {
        case let .stopContainer(id, _): "stop.\(id)"
        case let .removeContainer(id, _): "remove-container.\(id)"
        case let .removeImage(id, _): "remove-image.\(id)"
        case let .removeVolume(name): "remove-volume.\(name)"
        case .pruneBuilderCache: "prune-builder-cache"
        }
    }

    var title: String {
        switch self {
        case .stopContainer: "Stop Container?"
        case .removeContainer: "Remove Container?"
        case .removeImage: "Remove Image?"
        case .removeVolume: "Remove Volume?"
        case .pruneBuilderCache: "Prune Builder Cache?"
        }
    }

    var message: String {
        switch self {
        case let .stopContainer(_, name):
            "Docker will stop \(name)."
        case let .removeContainer(_, name):
            "Docker will remove \(name). Stopped containers can be recreated from their image."
        case let .removeImage(_, name):
            "Docker will remove \(name). Images used by containers may fail to remove "
                + "until those containers are removed."
        case let .removeVolume(name):
            "Docker will remove volume \(name). Volume data is not moved to the Trash."
        case .pruneBuilderCache:
            "Docker will remove reusable build cache layers."
        }
    }

    var confirmTitle: String {
        switch self {
        case .stopContainer: "Stop"
        case .removeContainer: "Remove"
        case .removeImage: "Remove"
        case .removeVolume: "Remove"
        case .pruneBuilderCache: "Prune"
        }
    }
}

private struct DockerMetricTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
