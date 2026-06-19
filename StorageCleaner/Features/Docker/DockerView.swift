import SwiftUI

struct DockerView: View {
    private let service: DockerService
    private let onDockerChanged: () -> Void

    @State private var snapshot: DockerSnapshot?
    @State private var isLoading = true
    @State private var selectedTab: DockerTab = .containers
    @State private var pendingAction: PendingDockerAction?
    @State private var actionMessage: String?

    init(
        service: DockerService = .live,
        onDockerChanged: @escaping () -> Void = {}
    ) {
        self.service = service
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
        .task { await load() }
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
        return "\(snapshot.containers.count) containers - \(snapshot.images.count) images - \(StorageFormatting.bytes(snapshot.totalBytes))"
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button {
                Task { await load() }
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                DockerMetricTile(title: "Images", value: "\(snapshot.images.count)", detail: StorageFormatting.bytes(snapshot.imageBytes))
                DockerMetricTile(title: "Containers", value: "\(snapshot.containers.count)", detail: StorageFormatting.bytes(snapshot.containerBytes))
                DockerMetricTile(title: "Volumes", value: "\(snapshot.volumes.count)", detail: StorageFormatting.bytes(snapshot.volumeBytes))
                DockerMetricTile(title: "Build Cache", value: "\(snapshot.builderCache.entryCount)", detail: StorageFormatting.bytes(snapshot.builderCache.bytes))
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
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
                        onStop: { pendingAction = .stopContainer(id: container.id, name: container.name) },
                        onRemove: { pendingAction = .removeContainer(id: container.id, name: container.name) }
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
                        onRemove: { pendingAction = .removeImage(id: image.id, name: image.displayName) }
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
                        onRemove: { pendingAction = .removeVolume(name: volume.name) }
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

                VStack(alignment: .leading, spacing: 3) {
                    Text("Builder Cache")
                        .font(.headline)
                    Text("\(cache.entryCount) entries - \(StorageFormatting.bytes(cache.bytes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    pendingAction = .pruneBuilderCache
                } label: {
                    Label("Prune", systemImage: "trash")
                }
                .disabled(cache.bytes == 0)
            }

            Text("Pruning removes reusable build layers. Docker can recreate them, but the next image build may take longer.")
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
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Reading Docker inventory...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notInstalledState: some View {
        AnimatedEmptyState(
            title: "Docker is not installed",
            message: "Install Docker Desktop or the Docker CLI to manage local images, containers, volumes, and build cache.",
            actionTitle: "Refresh",
            systemImage: "shippingbox",
            action: { Task { await load() } }
        )
        .frame(minHeight: 430)
    }

    private func daemonUnavailableState(_ snapshot: DockerSnapshot) -> some View {
        AnimatedEmptyState(
            title: "Docker is installed",
            message: snapshot.statusMessage,
            actionTitle: "Refresh",
            systemImage: "shippingbox.fill",
            action: { Task { await load() } }
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
            "Docker will remove \(name). Images used by containers may fail to remove until those containers are removed."
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

private struct DockerStateBadge: View {
    let title: String
    let isRunning: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isRunning ? AppTheme.mint : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((isRunning ? AppTheme.mint : Color.secondary).opacity(0.12), in: Capsule())
    }
}

private struct DockerContainerRow: View {
    let container: DockerContainer
    let stats: DockerContainerStats?
    let onStop: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: container.isRunning ? "play.circle.fill" : "stop.circle")
                .font(.title2)
                .foregroundStyle(container.isRunning ? AppTheme.mint : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(container.name)
                        .font(.headline)
                    DockerStateBadge(title: container.state.isEmpty ? "unknown" : container.state, isRunning: container.isRunning)
                }

                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 14) {
                    Label(StorageFormatting.bytes(container.writableBytes), systemImage: "internaldrive")
                    if container.virtualBytes > 0 {
                        Label("\(StorageFormatting.bytes(container.virtualBytes)) virtual", systemImage: "square.stack.3d.up")
                    }
                    if let stats {
                        Label(stats.cpuPercent, systemImage: "cpu")
                        Label(stats.memoryUsage, systemImage: "memorychip")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !container.status.isEmpty {
                    Text(container.status)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if container.isRunning {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                    }
                    .help("Stop container")
                }

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .help("Remove container")
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .cardSurface()
    }
}

private struct DockerImageRow: View {
    let image: DockerImage
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.stack.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(image.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(image.id) - \(image.createdSince)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(StorageFormatting.bytes(image.bytes))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Remove image")
        }
        .padding(16)
        .cardSurface()
    }
}

private struct DockerVolumeRow: View {
    let volume: DockerVolume
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.cyan)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text(volume.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(volume.mountpoint?.path ?? volume.driver)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(StorageFormatting.bytes(volume.bytes))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Remove volume")
        }
        .padding(16)
        .cardSurface()
    }
}

private struct DockerStatsRow: View {
    let stats: DockerContainerStats

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(AppTheme.mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 7) {
                Text(stats.name)
                    .font(.headline)

                HStack(spacing: 14) {
                    Label(stats.cpuPercent, systemImage: "cpu")
                    Label(stats.memoryUsage, systemImage: "memorychip")
                    Label(stats.networkIO, systemImage: "network")
                    Label(stats.blockIO, systemImage: "externaldrive")
                    Label("\(stats.pids) PIDs", systemImage: "number")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .cardSurface()
    }
}
