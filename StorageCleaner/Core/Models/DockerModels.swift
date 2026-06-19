import Foundation

struct DockerSnapshot: Sendable, Equatable {
    let isInstalled: Bool
    let daemonAvailable: Bool
    let version: String?
    let statusMessage: String
    let images: [DockerImage]
    let containers: [DockerContainer]
    let volumes: [DockerVolume]
    let builderCache: DockerBuilderCache
    let stats: [DockerContainerStats]

    var totalBytes: Int64 {
        imageBytes + containerBytes + volumeBytes + builderCache.bytes
    }

    var imageBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }
    var containerBytes: Int64 { containers.reduce(0) { $0 + $1.writableBytes } }
    var volumeBytes: Int64 { volumes.reduce(0) { $0 + $1.bytes } }

    var itemCount: Int {
        images.count + containers.count + volumes.count + builderCache.entryCount
    }

    var overviewExamples: [String] {
        let containerNames = containers.prefix(2).map(\.name)
        let imageNames = images.prefix(2).map(\.displayName)
        let volumeNames = volumes.prefix(2).map(\.name)
        return Array((containerNames + imageNames + volumeNames).prefix(3))
    }
}

struct DockerImage: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let repository: String
    let tag: String
    let bytes: Int64
    let createdSince: String

    var displayName: String {
        if repository == "<none>" && tag == "<none>" { return id }
        if tag.isEmpty || tag == "<none>" { return repository }
        return "\(repository):\(tag)"
    }
}

struct DockerContainer: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let name: String
    let image: String
    let state: String
    let status: String
    let ports: String
    let writableBytes: Int64
    let virtualBytes: Int64

    var isRunning: Bool {
        state.localizedCaseInsensitiveContains("running")
    }
}

struct DockerVolume: Identifiable, Sendable, Equatable, Hashable {
    let name: String
    let driver: String
    let mountpoint: URL?
    let bytes: Int64

    var id: String { name }
}

struct DockerBuilderCache: Sendable, Equatable, Hashable {
    let bytes: Int64
    let entryCount: Int

    static let empty = DockerBuilderCache(bytes: 0, entryCount: 0)
}

struct DockerContainerStats: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let name: String
    let cpuPercent: String
    let memoryUsage: String
    let memoryPercent: String
    let networkIO: String
    let blockIO: String
    let pids: String
}

struct DockerActionResult: Sendable, Equatable {
    let succeeded: Bool
    let message: String
}
