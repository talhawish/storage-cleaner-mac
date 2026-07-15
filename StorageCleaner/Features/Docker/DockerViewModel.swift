import Foundation

@MainActor
@Observable
final class DockerViewModel {
    private(set) var snapshot: DockerSnapshot?
    private(set) var isLoading = true
    private(set) var isPerformingAction = false
    var selectedTab: DockerTab = .containers
    var pendingAction: PendingDockerAction?
    private(set) var actionResult: DockerActionResult?

    @ObservationIgnored private let service: DockerService
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    init(service: DockerService) {
        self.service = service
    }

    var subtitle: String {
        guard let snapshot else { return "Checking Docker" }
        if !snapshot.isInstalled { return "Not installed" }
        if !snapshot.daemonAvailable { return "Installed, daemon unavailable" }
        return "\(snapshot.containers.count) containers · \(snapshot.images.count) images · "
            + StorageFormatting.bytes(snapshot.totalBytes)
    }

    func startLoading() {
        guard !isPerformingAction else { return }
        loadTask?.cancel()
        isLoading = true
        actionResult = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            let nextSnapshot = await service.loadSnapshot()
            guard !Task.isCancelled else { return }
            snapshot = nextSnapshot
            isLoading = false
            loadTask = nil
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }

    func perform(
        _ action: PendingDockerAction
    ) async -> (succeeded: Bool, cleanup: DockerCleanupEvent?) {
        guard !isPerformingAction else { return (false, nil) }
        isPerformingAction = true
        actionResult = nil
        defer { isPerformingAction = false }

        let before = snapshot
        let result: DockerActionResult
        switch action {
        case let .stopContainer(container):
            result = await service.stopContainer(id: container.id)
        case let .removeContainer(container):
            result = await service.removeContainer(id: container.id)
        case let .removeImage(image):
            result = await service.removeImage(id: image.id)
        case let .removeVolume(volume):
            result = await service.removeVolume(name: volume.name)
        case .pruneBuilderCache:
            result = await service.pruneBuilderCache()
        }

        actionResult = result
        guard result.succeeded else { return (false, nil) }

        isLoading = true
        let after = await service.loadSnapshot()
        snapshot = after
        isLoading = false

        guard action.isCleanup else { return (true, nil) }
        let measuredReclaimed = max(0, (before?.totalBytes ?? 0) - after.totalBytes)
        let estimatedReclaimed = before?.diskUsage == nil || after.diskUsage == nil
            ? action.estimatedBytes
            : measuredReclaimed
        return (
            true,
            DockerCleanupEvent(bytesReclaimed: estimatedReclaimed, itemCount: action.cleanupItemCount)
        )
    }
}
