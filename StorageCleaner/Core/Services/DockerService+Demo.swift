import Foundation

extension DockerService {
    static func demo() -> DockerService {
        DockerService(
            locateDocker: { URL(fileURLWithPath: "/usr/local/bin/docker") },
            isDockerDesktopInstalled: { true },
            runCommand: { _, arguments in
                demoOutput(for: arguments)
            }
        )
    }

    private static func demoOutput(for arguments: [String]) -> CommandOutput {
        switch arguments.joined(separator: " ") {
        case "version --format {{.Server.Version}}":
            .init(exitCode: 0, output: "29.0.1")
        case "info --format {{json .}}":
            .init(exitCode: 0, output: "{}")
        case "image ls --all --format {{json .}}":
            .init(exitCode: 0, output: demoImages)
        case "container ls --all --size --format {{json .}}":
            .init(exitCode: 0, output: demoContainers)
        case "volume ls --format {{json .}}":
            .init(exitCode: 0, output: demoVolumes)
        case "stats --no-stream --format {{json .}}":
            .init(exitCode: 0, output: demoStats)
        case "system df --format {{json .}}":
            .init(exitCode: 0, output: demoDiskUsage)
        case "system df --verbose --format {{json .}}":
            .init(exitCode: 0, output: demoDetailedDiskUsage)
        case "builder prune --force":
            .init(exitCode: 0, output: "Total reclaimed space: 1.4GB")
        default:
            .init(exitCode: 0, output: arguments.last ?? "")
        }
    }

    private static let demoImages = [
        #"{"ID":"sha256:redis","Repository":"redis","Tag":"7-alpine","Size":"117MB","#
            + #""CreatedSince":"2 weeks ago"}"#,
        #"{"ID":"sha256:api","Repository":"storage-cleaner-api","Tag":"dev","Size":"842MB","#
            + #""CreatedSince":"3 days ago"}"#
    ].joined(separator: "\n")

    private static let demoContainers = [
        #"{"ID":"api-dev","Names":"api-dev","Image":"storage-cleaner-api:dev","State":"running","#
            + #""Status":"Up 3 hours","Ports":"3000/tcp","Size":"48MB (virtual 842MB)"}"#,
        #"{"ID":"redis-dev","Names":"redis-dev","Image":"redis:7-alpine","State":"exited","#
            + #""Status":"Exited (0) 2 days ago","Ports":"","Size":"12MB (virtual 117MB)"}"#
    ].joined(separator: "\n")

    private static let demoVolumes = [
        #"{"Name":"project-postgres-data","Driver":"local","#
            + #""Mountpoint":"/var/lib/docker/volumes/project-postgres-data/_data"}"#,
        #"{"Name":"old-build-output","Driver":"local","#
            + #""Mountpoint":"/var/lib/docker/volumes/old-build-output/_data"}"#
    ].joined(separator: "\n")

    private static let demoStats =
        #"{"Container":"api-dev","Name":"api-dev","CPUPerc":"0.35%","MemUsage":"186MiB / 4GiB","#
        + #""MemPerc":"4.5%","NetIO":"1.2MB / 640kB","BlockIO":"18MB / 4MB","PIDs":"14"}"#

    private static let demoDiskUsage = [
        #"{"Type":"Images","TotalCount":"2","Active":"2","Size":"790MB","Reclaimable":"125MB (15%)"}"#,
        #"{"Type":"Containers","TotalCount":"2","Active":"1","Size":"60MB","Reclaimable":"12MB (20%)"}"#,
        #"{"Type":"Local Volumes","TotalCount":"2","Active":"1","Size":"2.8GB","Reclaimable":"640MB (22%)"}"#,
        #"{"Type":"Build Cache","TotalCount":"34","Active":"6","Size":"3.2GB","Reclaimable":"1.4GB"}"#
    ].joined(separator: "\n")

    private static let demoDetailedDiskUsage = #"{"Images":["#
        + #"{"ID":"sha256:redis","SharedSize":"32MB","UniqueSize":"85MB","Containers":"1"},"#
        + #"{"ID":"sha256:api","SharedSize":"170MB","UniqueSize":"672MB","Containers":"1"}],"#
        + #""Containers":[],"Volumes":["#
        + #"{"Name":"project-postgres-data","Links":"1","Size":"2.16GB"},"#
        + #"{"Name":"old-build-output","Links":"0","Size":"640MB"}],"BuildCache":[]}"#
}
