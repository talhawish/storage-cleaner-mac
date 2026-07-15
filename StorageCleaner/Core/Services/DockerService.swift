import Foundation

struct DockerService: Sendable {
    struct CommandOutput: Sendable, Equatable {
        let exitCode: Int32
        let output: String
        var succeeded: Bool { exitCode == 0 }
    }

    var locateDocker: @Sendable () -> URL?
    var isDockerDesktopInstalled: @Sendable () -> Bool
    var runCommand: @Sendable (_ tool: URL, _ arguments: [String]) async -> CommandOutput

    var isInstalled: Bool {
        locateDocker() != nil || isDockerDesktopInstalled()
    }

    func loadSnapshot() async -> DockerSnapshot {
        guard let docker = locateDocker() else {
            return DockerSnapshot(
                isInstalled: isInstalled,
                daemonAvailable: false,
                version: nil,
                statusMessage: isInstalled
                    ? "Docker Desktop is installed, but the Docker CLI was not found."
                    : "Docker is not installed on this Mac.",
                images: [],
                containers: [],
                volumes: [],
                builderCache: .empty,
                stats: [],
                diskUsage: nil,
                warnings: []
            )
        }

        let version = await dockerVersion(using: docker)
        let info = await runCommand(docker, ["info", "--format", "{{json .}}"])
        guard info.succeeded else {
            return DockerSnapshot(
                isInstalled: true,
                daemonAvailable: false,
                version: version,
                statusMessage: Self.firstMeaningfulLine(info.output)
                    ?? "Docker is installed, but the daemon is not reachable.",
                images: [],
                containers: [],
                volumes: [],
                builderCache: .empty,
                stats: [],
                diskUsage: nil,
                warnings: []
            )
        }

        return await loadAvailableSnapshot(using: docker, version: version)
    }

    private func loadAvailableSnapshot(using docker: URL, version: String?) async -> DockerSnapshot {
        async let images = listImages(using: docker)
        async let containers = listContainers(using: docker)
        async let volumes = listVolumes(using: docker)
        async let stats = listStats(using: docker)
        async let diskUsage = diskUsageSummary(using: docker)
        async let details = detailedDiskUsage(using: docker)

        let imageResult = await images
        let containerResult = await containers
        let volumeResult = await volumes
        let statsResult = await stats
        let usageResult = await diskUsage
        let detailsResult = await details

        let enrichedImages = Self.enrichImages(imageResult.items, with: detailsResult.images)
        let enrichedVolumes = Self.enrichVolumes(volumeResult.items, with: detailsResult.volumes)
        let builderUsage = usageResult.usage?.buildCache ?? .empty
        let warnings = [
            imageResult.warning,
            containerResult.warning,
            volumeResult.warning,
            statsResult.warning,
            usageResult.warning,
            detailsResult.warning
        ].compactMap { $0 }

        return DockerSnapshot(
            isInstalled: true,
            daemonAvailable: true,
            version: version,
            statusMessage: "Docker is running.",
            images: enrichedImages,
            containers: containerResult.items,
            volumes: enrichedVolumes,
            builderCache: DockerBuilderCache(
                bytes: builderUsage.usedBytes,
                entryCount: builderUsage.totalCount,
                reclaimableBytes: builderUsage.reclaimableBytes
            ),
            stats: statsResult.items,
            diskUsage: usageResult.usage,
            warnings: warnings
        )
    }

    func stopContainer(id: String) async -> DockerActionResult {
        await runDockerAction(arguments: ["stop", id], success: "Container stopped.")
    }

    func removeContainer(id: String) async -> DockerActionResult {
        await runDockerAction(arguments: ["rm", id], success: "Container removed.")
    }

    func removeImage(id: String) async -> DockerActionResult {
        await runDockerAction(arguments: ["image", "rm", id], success: "Image removed.")
    }

    func removeVolume(name: String) async -> DockerActionResult {
        await runDockerAction(arguments: ["volume", "rm", name], success: "Volume removed.")
    }

    func pruneBuilderCache() async -> DockerActionResult {
        await runDockerAction(arguments: ["builder", "prune", "--force"], success: "Builder cache pruned.")
    }

    private func runDockerAction(arguments: [String], success: String) async -> DockerActionResult {
        guard let docker = locateDocker() else {
            return DockerActionResult(succeeded: false, message: "Docker CLI was not found.")
        }
        let output = await runCommand(docker, arguments)
        return DockerActionResult(
            succeeded: output.succeeded,
            message: output.succeeded
                ? success
                : (Self.firstMeaningfulLine(output.output) ?? "Docker reported an error.")
        )
    }
}

// MARK: - Inventory

extension DockerService {
    private func dockerVersion(using docker: URL) async -> String? {
        let output = await runCommand(docker, ["version", "--format", "{{.Server.Version}}"])
        guard output.succeeded else { return nil }
        let version = output.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    private func listImages(using docker: URL) async -> (items: [DockerImage], warning: String?) {
        let output = await runCommand(docker, ["image", "ls", "--all", "--format", "{{json .}}"])
        guard output.succeeded else {
            return ([], Self.inventoryWarning(for: "images", output: output))
        }
        let images = Self.jsonObjects(fromJSONLines: output.output).compactMap { object -> DockerImage? in
            guard let id = object["ID"] as? String else { return nil }
            let repository = object["Repository"] as? String ?? "<none>"
            let tag = object["Tag"] as? String ?? ""
            let size = object["Size"] as? String ?? ""
            return DockerImage(
                id: id,
                repository: repository,
                tag: tag,
                bytes: Self.parseByteCount(size) ?? 0,
                createdSince: object["CreatedSince"] as? String ?? "",
                sharedBytes: nil,
                uniqueBytes: nil,
                containerCount: nil
            )
        }
        .sorted { $0.bytes > $1.bytes }
        return (images, nil)
    }

    private func listContainers(using docker: URL) async -> (items: [DockerContainer], warning: String?) {
        let output = await runCommand(docker, ["container", "ls", "--all", "--size", "--format", "{{json .}}"])
        guard output.succeeded else {
            return ([], Self.inventoryWarning(for: "containers", output: output))
        }
        let containers = Self.jsonObjects(fromJSONLines: output.output).compactMap { object -> DockerContainer? in
            guard let id = object["ID"] as? String else { return nil }
            let size = Self.parseContainerSize(object["Size"] as? String ?? "")
            return DockerContainer(
                id: id,
                name: object["Names"] as? String ?? id,
                image: object["Image"] as? String ?? "",
                state: object["State"] as? String ?? "",
                status: object["Status"] as? String ?? "",
                ports: object["Ports"] as? String ?? "",
                writableBytes: size.writable,
                virtualBytes: size.virtual
            )
        }
        .sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning && !$1.isRunning }
            return $0.writableBytes > $1.writableBytes
        }
        return (containers, nil)
    }

    private func listVolumes(using docker: URL) async -> (items: [DockerVolume], warning: String?) {
        let output = await runCommand(docker, ["volume", "ls", "--format", "{{json .}}"])
        guard output.succeeded else {
            return ([], Self.inventoryWarning(for: "volumes", output: output))
        }
        let volumes = Self.jsonObjects(fromJSONLines: output.output).compactMap { object -> DockerVolume? in
            guard let name = object["Name"] as? String else { return nil }
            let path = object["Mountpoint"] as? String
            return DockerVolume(
                name: name,
                driver: object["Driver"] as? String ?? "",
                mountpoint: path.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) },
                bytes: 0,
                linkCount: nil
            )
        }
        return (volumes, nil)
    }

    private func listStats(using docker: URL) async -> (items: [DockerContainerStats], warning: String?) {
        let output = await runCommand(docker, ["stats", "--no-stream", "--format", "{{json .}}"])
        guard output.succeeded else {
            return ([], Self.inventoryWarning(for: "live statistics", output: output))
        }
        let stats = Self.jsonObjects(fromJSONLines: output.output).compactMap { object -> DockerContainerStats? in
            guard let id = object["Container"] as? String else { return nil }
            return DockerContainerStats(
                id: id,
                name: object["Name"] as? String ?? id,
                cpuPercent: object["CPUPerc"] as? String ?? "0%",
                memoryUsage: object["MemUsage"] as? String ?? "0 B",
                memoryPercent: object["MemPerc"] as? String ?? "0%",
                networkIO: object["NetIO"] as? String ?? "0 B / 0 B",
                blockIO: object["BlockIO"] as? String ?? "0 B / 0 B",
                pids: object["PIDs"] as? String ?? "0"
            )
        }
        return (stats, nil)
    }

    private func diskUsageSummary(
        using docker: URL
    ) async -> (usage: DockerDiskUsage?, warning: String?) {
        let output = await runCommand(docker, ["system", "df", "--format", "{{json .}}"])
        guard output.succeeded else {
            return (nil, Self.inventoryWarning(for: "disk usage", output: output))
        }
        guard let usage = Self.parseDiskUsage(output.output) else {
            return (nil, "Docker returned an unreadable disk-usage summary.")
        }
        return (usage, nil)
    }

    private func detailedDiskUsage(using docker: URL) async -> DockerDiskUsageDetails {
        let output = await runCommand(
            docker,
            ["system", "df", "--verbose", "--format", "{{json .}}"]
        )
        guard output.succeeded else {
            return .unavailable(
                warning: Self.inventoryWarning(for: "per-resource disk usage", output: output)
            )
        }
        guard let data = output.output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return .unavailable(warning: "Docker returned unreadable per-resource disk usage.")
        }

        let images = Self.imageDiskUsage(from: object["Images"] as? [[String: Any]] ?? [])
        let volumes = Self.volumeDiskUsage(from: object["Volumes"] as? [[String: Any]] ?? [])
        return DockerDiskUsageDetails(images: images, volumes: volumes, warning: nil)
    }
}

// MARK: - Parsing

extension DockerService {
    static func parseDiskUsage(_ output: String) -> DockerDiskUsage? {
        let objects = jsonObjects(fromJSONLines: output)
        guard !objects.isEmpty else { return nil }

        var categories: [DockerResourceKind: DockerDiskUsageCategory] = [:]
        for object in objects {
            guard let typeName = object["Type"] as? String,
                  let kind = DockerResourceKind(rawValue: typeName)
            else {
                continue
            }
            categories[kind] = DockerDiskUsageCategory(
                totalCount: integer(from: object["TotalCount"]),
                activeCount: integer(from: object["Active"]),
                usedBytes: byteCount(from: object["Size"]),
                reclaimableBytes: byteCount(from: object["Reclaimable"])
            )
        }
        guard !categories.isEmpty else { return nil }
        return DockerDiskUsage(
            images: categories[.images] ?? .empty,
            containers: categories[.containers] ?? .empty,
            volumes: categories[.volumes] ?? .empty,
            buildCache: categories[.buildCache] ?? .empty
        )
    }

    static func jsonObjects(fromJSONLines output: String) -> [[String: Any]] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> [String: Any]? in
                guard let data = String(line).data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    return nil
                }
                return object
            }
    }

    static func parseContainerSize(_ value: String) -> (writable: Int64, virtual: Int64) {
        let matches = byteMatches(in: value)
        return (
            writable: matches.first ?? 0,
            virtual: matches.dropFirst().first ?? 0
        )
    }

    static func parseByteCount(_ value: String) -> Int64? {
        byteMatches(in: value).first
    }

    private static func imageDiskUsage(
        from objects: [[String: Any]]
    ) -> [String: [String: Int64]] {
        Dictionary(
            objects.compactMap { object -> (String, [String: Int64])? in
                guard let id = object["ID"] as? String else { return nil }
                return (
                    id,
                    [
                        "shared": byteCount(from: object["SharedSize"]),
                        "unique": byteCount(from: object["UniqueSize"]),
                        "containers": Int64(integer(from: object["Containers"]))
                    ]
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func volumeDiskUsage(
        from objects: [[String: Any]]
    ) -> [String: [String: Int64]] {
        Dictionary(
            objects.compactMap { object -> (String, [String: Int64])? in
                guard let name = object["Name"] as? String else { return nil }
                return (
                    name,
                    [
                        "bytes": byteCount(from: object["Size"]),
                        "links": Int64(integer(from: object["Links"]))
                    ]
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func enrichImages(
        _ images: [DockerImage],
        with details: [String: [String: Int64]]
    ) -> [DockerImage] {
        images.map { image in
            let detail = details.first { key, _ in
                key.hasPrefix(image.id) || image.id.hasPrefix(key)
            }?.value
            return DockerImage(
                id: image.id,
                repository: image.repository,
                tag: image.tag,
                bytes: image.bytes,
                createdSince: image.createdSince,
                sharedBytes: detail?["shared"],
                uniqueBytes: detail?["unique"],
                containerCount: detail?["containers"].map(Int.init)
            )
        }
    }

    private static func enrichVolumes(
        _ volumes: [DockerVolume],
        with details: [String: [String: Int64]]
    ) -> [DockerVolume] {
        volumes.map { volume in
            let detail = details[volume.name]
            return DockerVolume(
                name: volume.name,
                driver: volume.driver,
                mountpoint: volume.mountpoint,
                bytes: detail?["bytes"] ?? 0,
                linkCount: detail?["links"].map(Int.init)
            )
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private static func integer(from value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? Int64 { return Int(clamping: value) }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private static func byteCount(from value: Any?) -> Int64 {
        if let value = value as? Int64 { return max(0, value) }
        if let value = value as? Int { return Int64(max(0, value)) }
        if let value = value as? String { return parseByteCount(value) ?? 0 }
        return 0
    }

    private static func inventoryWarning(for subject: String, output: CommandOutput) -> String {
        let detail = firstMeaningfulLine(output.output) ?? "Docker reported an error."
        return "Couldn't read Docker \(subject): \(detail)"
    }

    private static func byteMatches(in value: String) -> [Int64] {
        let normalized = value.replacing(",", with: "")
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGTPE]?i?B|[KMGTPE]?B|B)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        return regex.matches(in: normalized, range: range).compactMap { match in
            guard match.numberOfRanges >= 3,
                  let numberRange = Range(match.range(at: 1), in: normalized),
                  let unitRange = Range(match.range(at: 2), in: normalized),
                  let number = Double(normalized[numberRange])
            else {
                return nil
            }
            let bytes = number * multiplier(for: String(normalized[unitRange]))
            guard bytes.isFinite, bytes >= 0, bytes <= Double(Int64.max) else { return nil }
            return Int64(bytes)
        }
    }

    private static func multiplier(for unit: String) -> Double {
        byteMultipliers[unit.lowercased(), default: 1]
    }

    private static let byteMultipliers: [String: Double] = [
        "b": 1,
        "kb": 1_000,
        "kib": 1_024,
        "mb": 1_000_000,
        "mib": 1_048_576,
        "gb": 1_000_000_000,
        "gib": 1_073_741_824,
        "tb": 1_000_000_000_000,
        "tib": 1_099_511_627_776,
        "pb": 1_000_000_000_000_000,
        "pib": 1_125_899_906_842_624,
        "eb": 1_000_000_000_000_000_000,
        "eib": 1_152_921_504_606_846_976
    ]

    private static func firstMeaningfulLine(_ output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}

// MARK: - Live

extension DockerService {
    static let live = DockerService(
        locateDocker: {
            let fileManager = FileManager.default
            let environmentPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
                .split(separator: ":")
                .map { URL(fileURLWithPath: String($0)).appendingPathComponent("docker") }
            let candidates = [
                URL(fileURLWithPath: "/usr/local/bin/docker"),
                URL(fileURLWithPath: "/opt/homebrew/bin/docker"),
                URL(fileURLWithPath: "/Applications/Docker.app/Contents/Resources/bin/docker")
            ] + environmentPaths

            return candidates.first { fileManager.isExecutableFile(atPath: $0.path) }
        },
        isDockerDesktopInstalled: {
            FileManager.default.fileExists(atPath: "/Applications/Docker.app")
        },
        runCommand: { tool, arguments in
            do {
                let result = try await SystemProcessExecutor().run(
                    executable: tool,
                    arguments: arguments
                )
                let standardOutput = String(data: result.standardOutput, encoding: .utf8) ?? ""
                let standardError = String(data: result.standardError, encoding: .utf8) ?? ""
                let separator = standardOutput.isEmpty || standardError.isEmpty ? "" : "\n"
                return CommandOutput(
                    exitCode: result.exitCode,
                    output: standardOutput + separator + standardError
                )
            } catch {
                return CommandOutput(exitCode: -1, output: error.localizedDescription)
            }
        }
    )
}
