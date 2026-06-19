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
    var measure: @Sendable (_ url: URL) -> Int64

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
                stats: []
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
                stats: []
            )
        }

        async let images = listImages(using: docker)
        async let containers = listContainers(using: docker)
        async let volumes = listVolumes(using: docker)
        async let builderCache = builderCacheSummary(using: docker)
        async let stats = listStats(using: docker)

        return await DockerSnapshot(
            isInstalled: true,
            daemonAvailable: true,
            version: version,
            statusMessage: "Docker is running.",
            images: images,
            containers: containers,
            volumes: volumes,
            builderCache: builderCache,
            stats: stats
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
            message: output.succeeded ? success : (Self.firstMeaningfulLine(output.output) ?? "Docker reported an error.")
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

    private func listImages(using docker: URL) async -> [DockerImage] {
        let output = await runCommand(docker, ["image", "ls", "--all", "--format", "{{json .}}"])
        guard output.succeeded else { return [] }
        return Self.jsonObjects(fromJSONLines: output.output).compactMap { object in
            guard let id = object["ID"] as? String else { return nil }
            let repository = object["Repository"] as? String ?? "<none>"
            let tag = object["Tag"] as? String ?? ""
            let size = object["Size"] as? String ?? ""
            return DockerImage(
                id: id,
                repository: repository,
                tag: tag,
                bytes: Self.parseByteCount(size) ?? 0,
                createdSince: object["CreatedSince"] as? String ?? ""
            )
        }
        .sorted { $0.bytes > $1.bytes }
    }

    private func listContainers(using docker: URL) async -> [DockerContainer] {
        let output = await runCommand(docker, ["container", "ls", "--all", "--size", "--format", "{{json .}}"])
        guard output.succeeded else { return [] }
        return Self.jsonObjects(fromJSONLines: output.output).compactMap { object in
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
    }

    private func listVolumes(using docker: URL) async -> [DockerVolume] {
        let output = await runCommand(docker, ["volume", "ls", "--format", "{{json .}}"])
        guard output.succeeded else { return [] }

        var volumes: [DockerVolume] = []
        for object in Self.jsonObjects(fromJSONLines: output.output) {
            guard let name = object["Name"] as? String else { continue }
            let driver = object["Driver"] as? String ?? ""
            let mountpoint = await inspectVolumeMountpoint(name: name, using: docker)
            let bytes = mountpoint.map(measure) ?? 0
            volumes.append(DockerVolume(name: name, driver: driver, mountpoint: mountpoint, bytes: bytes))
        }
        return volumes.sorted { $0.bytes > $1.bytes }
    }

    private func inspectVolumeMountpoint(name: String, using docker: URL) async -> URL? {
        let output = await runCommand(docker, ["volume", "inspect", name, "--format", "{{json .}}"])
        guard output.succeeded,
              let object = Self.jsonObjects(fromJSONLines: output.output).first,
              let path = object["Mountpoint"] as? String,
              !path.isEmpty
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func builderCacheSummary(using docker: URL) async -> DockerBuilderCache {
        let output = await runCommand(docker, ["builder", "du", "--verbose", "--format", "{{json .}}"])
        guard output.succeeded else { return .empty }

        let sizes = Self.jsonObjects(fromJSONLines: output.output).compactMap { object -> Int64? in
            if let size = object["Size"] as? String { return Self.parseByteCount(size) }
            if let size = object["Size"] as? Int64 { return size }
            if let size = object["Size"] as? Int { return Int64(size) }
            return nil
        }
        return DockerBuilderCache(bytes: sizes.reduce(0, +), entryCount: sizes.count)
    }

    private func listStats(using docker: URL) async -> [DockerContainerStats] {
        let output = await runCommand(docker, ["stats", "--no-stream", "--format", "{{json .}}"])
        guard output.succeeded else { return [] }
        return Self.jsonObjects(fromJSONLines: output.output).compactMap { object in
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
    }
}

// MARK: - Parsing

extension DockerService {
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

    private static func byteMatches(in value: String) -> [Int64] {
        let normalized = value.replacingOccurrences(of: ",", with: "")
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
            return Int64(number * multiplier(for: String(normalized[unitRange])))
        }
    }

    private static func multiplier(for unit: String) -> Double {
        switch unit.lowercased() {
        case "b": 1
        case "kb": 1_000
        case "kib": 1_024
        case "mb": 1_000_000
        case "mib": 1_048_576
        case "gb": 1_000_000_000
        case "gib": 1_073_741_824
        case "tb": 1_000_000_000_000
        case "tib": 1_099_511_627_776
        default: 1
        }
    }

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
            await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = tool
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    return CommandOutput(exitCode: -1, output: error.localizedDescription)
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return CommandOutput(
                    exitCode: process.terminationStatus,
                    output: String(bytes: data, encoding: .utf8) ?? ""
                )
            }.value
        },
        measure: { StorageFormatting.itemSize(at: $0) }
    )
}
