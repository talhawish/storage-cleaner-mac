import Foundation

struct DockerDiskUsageCategory: Sendable, Equatable {
    let totalCount: Int
    let activeCount: Int
    let usedBytes: Int64
    let reclaimableBytes: Int64

    static let empty = DockerDiskUsageCategory(
        totalCount: 0,
        activeCount: 0,
        usedBytes: 0,
        reclaimableBytes: 0
    )
}
