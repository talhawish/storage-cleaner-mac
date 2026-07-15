import Foundation

struct DockerDiskUsageDetails: Sendable {
    let images: [String: [String: Int64]]
    let volumes: [String: [String: Int64]]
    let warning: String?

    static func unavailable(warning: String) -> DockerDiskUsageDetails {
        DockerDiskUsageDetails(images: [:], volumes: [:], warning: warning)
    }
}
