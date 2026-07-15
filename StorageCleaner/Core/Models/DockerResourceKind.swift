import Foundation

enum DockerResourceKind: String, CaseIterable, Sendable {
    case images = "Images"
    case containers = "Containers"
    case volumes = "Local Volumes"
    case buildCache = "Build Cache"
}
