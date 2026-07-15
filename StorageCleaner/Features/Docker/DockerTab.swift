import Foundation

enum DockerTab: String, CaseIterable, Identifiable {
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
