import SwiftUI

struct DockerStateBadge: View {
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

struct DockerContainerRow: View {
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
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(container.name)
                        .font(.headline)
                    DockerStateBadge(
                        title: container.state.isEmpty ? "unknown" : container.state,
                        isRunning: container.isRunning
                    )
                }

                Text(container.image)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                containerMetadata

                if !container.status.isEmpty {
                    Text(container.status)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            actionButtons
        }
        .padding(16)
        .cardSurface()
    }

    private var containerMetadata: some View {
        HStack(spacing: 14) {
            Label(StorageFormatting.bytes(container.writableBytes), systemImage: "internaldrive")
            if container.virtualBytes > 0 {
                Label(
                    "\(StorageFormatting.bytes(container.virtualBytes)) virtual",
                    systemImage: "square.stack.3d.up"
                )
            }
            if let stats {
                Label(stats.cpuPercent, systemImage: "cpu")
                Label(stats.memoryUsage, systemImage: "memorychip")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if container.isRunning {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .accessibilityHidden(true)
                }
                .accessibilityLabel("Stop container")
                .help("Stop container")
            }

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Remove container")
            .help("Remove container")
        }
        .buttonStyle(.bordered)
    }
}

struct DockerImageRow: View {
    let image: DockerImage
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.stack.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.violet)
                .frame(width: 28)
                .accessibilityHidden(true)

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
                    .accessibilityHidden(true)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Remove image")
            .help("Remove image")
        }
        .padding(16)
        .cardSurface()
    }
}

struct DockerVolumeRow: View {
    let volume: DockerVolume
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "externaldrive.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.cyan)
                .frame(width: 28)
                .accessibilityHidden(true)

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
                    .accessibilityHidden(true)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Remove volume")
            .help("Remove volume")
        }
        .padding(16)
        .cardSurface()
    }
}

struct DockerStatsRow: View {
    let stats: DockerContainerStats

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
                .foregroundStyle(AppTheme.mint)
                .frame(width: 28)
                .accessibilityHidden(true)

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
