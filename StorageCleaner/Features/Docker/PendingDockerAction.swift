import Foundation

enum PendingDockerAction: Identifiable, Sendable {
    case stopContainer(DockerContainer)
    case removeContainer(DockerContainer)
    case removeImage(DockerImage)
    case removeVolume(DockerVolume)
    case pruneBuilderCache(DockerBuilderCache)

    var id: String {
        switch self {
        case let .stopContainer(container): "stop.\(container.id)"
        case let .removeContainer(container): "remove-container.\(container.id)"
        case let .removeImage(image): "remove-image.\(image.id)"
        case let .removeVolume(volume): "remove-volume.\(volume.name)"
        case .pruneBuilderCache: "prune-builder-cache"
        }
    }

    var title: String {
        switch self {
        case .stopContainer: "Stop Container?"
        case .removeContainer: "Remove Container?"
        case .removeImage: "Remove Image?"
        case .removeVolume: "Permanently Remove Volume?"
        case .pruneBuilderCache: "Prune Builder Cache?"
        }
    }

    var itemName: String {
        switch self {
        case let .stopContainer(container), let .removeContainer(container): container.name
        case let .removeImage(image): image.displayName
        case let .removeVolume(volume): volume.name
        case .pruneBuilderCache: "Reusable build layers"
        }
    }

    var estimatedBytes: Int64 {
        switch self {
        case .stopContainer: 0
        case let .removeContainer(container): container.writableBytes
        case let .removeImage(image): image.uniqueBytes ?? image.bytes
        case let .removeVolume(volume): volume.bytes
        case let .pruneBuilderCache(cache): cache.reclaimableBytes
        }
    }

    var isCleanup: Bool {
        if case .stopContainer = self { false } else { true }
    }

    var cleanupItemCount: Int {
        switch self {
        case let .pruneBuilderCache(cache): max(cache.entryCount, 1)
        case .stopContainer: 0
        case .removeContainer, .removeImage, .removeVolume: 1
        }
    }

    var isIrreversible: Bool {
        switch self {
        case .stopContainer: false
        case .removeContainer, .removeImage, .removeVolume, .pruneBuilderCache: true
        }
    }

    var explanation: String {
        switch self {
        case .stopContainer:
            "Docker sends the container its configured stop signal. Its writable data remains available."
        case .removeContainer:
            "The container and its writable layer are removed. Named volumes and the source image remain."
        case .removeImage:
            "The local image is removed. Shared layers may remain when another image uses them, and the image "
                + "can be pulled or rebuilt again."
        case .removeVolume:
            "The volume and all data stored in it are permanently deleted by Docker. It is not moved to the Trash."
        case .pruneBuilderCache:
            "Docker removes build-cache records that are currently reclaimable. Future image builds may take longer."
        }
    }

    var confirmTitle: String {
        switch self {
        case .stopContainer: "Stop"
        case .removeContainer, .removeImage, .removeVolume: "Remove"
        case .pruneBuilderCache: "Prune"
        }
    }
}
