import Foundation

struct DockerDiskUsage: Sendable, Equatable {
    let images: DockerDiskUsageCategory
    let containers: DockerDiskUsageCategory
    let volumes: DockerDiskUsageCategory
    let buildCache: DockerDiskUsageCategory

    var totalBytes: Int64 {
        images.usedBytes + containers.usedBytes + volumes.usedBytes + buildCache.usedBytes
    }

    var reclaimableBytes: Int64 {
        images.reclaimableBytes
            + containers.reclaimableBytes
            + volumes.reclaimableBytes
            + buildCache.reclaimableBytes
    }

    func category(for kind: DockerResourceKind) -> DockerDiskUsageCategory {
        switch kind {
        case .images: images
        case .containers: containers
        case .volumes: volumes
        case .buildCache: buildCache
        }
    }
}
