import Foundation
import XCTest
@testable import StorageCleaner

final class DockerServiceTests: XCTestCase {
    func testParsesDockerByteCounts() {
        XCTAssertEqual(DockerService.parseByteCount("1.5GB"), 1_500_000_000)
        XCTAssertEqual(DockerService.parseByteCount("24.25MB"), 24_250_000)
        XCTAssertEqual(DockerService.parseByteCount("512kB"), 512_000)
        XCTAssertEqual(DockerService.parseByteCount("10B"), 10)
    }

    func testParsesContainerWritableAndVirtualSizes() {
        let parsed = DockerService.parseContainerSize("12.3MB (virtual 250MB)")

        XCTAssertEqual(parsed.writable, 12_300_000)
        XCTAssertEqual(parsed.virtual, 250_000_000)
    }

    func testSnapshotAggregatesDockerInventory() async {
        let docker = URL(fileURLWithPath: "/usr/local/bin/docker")
        let outputs = Self.dockerInventoryOutputs

        let service = DockerService(
            locateDocker: { docker },
            isDockerDesktopInstalled: { true },
            runCommand: { _, arguments in
                outputs[arguments.joined(separator: " ")] ?? .init(exitCode: 1, output: "missing")
            }
        )

        let snapshot = await service.loadSnapshot()

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertTrue(snapshot.daemonAvailable)
        XCTAssertEqual(snapshot.version, "26.1.0")
        XCTAssertEqual(snapshot.images.count, 1)
        XCTAssertEqual(snapshot.containers.count, 1)
        XCTAssertEqual(snapshot.volumes.count, 1)
        XCTAssertEqual(snapshot.stats.count, 1)
        XCTAssertEqual(snapshot.builderCache.entryCount, 8)
        XCTAssertEqual(snapshot.builderCache.reclaimableBytes, 30_000_000)
        XCTAssertEqual(snapshot.totalBytes, 169_000_000)
        XCTAssertEqual(snapshot.reclaimableBytes, 72_000_000)
        XCTAssertEqual(snapshot.images.first?.uniqueBytes, 80_000_000)
        XCTAssertEqual(snapshot.images.first?.sharedBytes, 40_000_000)
        XCTAssertEqual(snapshot.images.first?.containerCount, 1)
        XCTAssertEqual(snapshot.volumes.first?.bytes, 7_000_000)
        XCTAssertEqual(snapshot.volumes.first?.linkCount, 0)
        XCTAssertTrue(snapshot.warnings.isEmpty)
    }

    func testSnapshotReportsInstalledWhenDesktopExistsButCLIIsMissing() async {
        let service = DockerService(
            locateDocker: { nil },
            isDockerDesktopInstalled: { true },
            runCommand: { _, _ in .init(exitCode: 1, output: "") }
        )

        let snapshot = await service.loadSnapshot()

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertFalse(snapshot.daemonAvailable)
    }

    func testParsesCanonicalDiskUsageWithoutDoubleCountingSharedLayers() throws {
        let usage = try XCTUnwrap(DockerService.parseDiskUsage(Self.diskUsageSummary))

        XCTAssertEqual(usage.images.usedBytes, 100_000_000)
        XCTAssertEqual(usage.images.reclaimableBytes, 40_000_000)
        XCTAssertEqual(usage.volumes.activeCount, 1)
        XCTAssertEqual(usage.totalBytes, 169_000_000)
        XCTAssertEqual(usage.reclaimableBytes, 72_000_000)
    }

    func testPartialInventoryFailureIsSurfacedInsteadOfLookingEmpty() async {
        let docker = URL(fileURLWithPath: "/usr/local/bin/docker")
        let service = DockerService(
            locateDocker: { docker },
            isDockerDesktopInstalled: { true },
            runCommand: { _, arguments in
                if arguments.first == "version" { return .init(exitCode: 0, output: "26.1.0") }
                if arguments.first == "info" { return .init(exitCode: 0, output: "{}") }
                return .init(exitCode: 1, output: "permission denied")
            }
        )

        let snapshot = await service.loadSnapshot()

        XCTAssertTrue(snapshot.daemonAvailable)
        XCTAssertTrue(snapshot.images.isEmpty)
        XCTAssertTrue(snapshot.warnings.contains { $0.contains("images") && $0.contains("permission denied") })
        XCTAssertTrue(snapshot.warnings.contains { $0.contains("disk usage") })
    }

    func testDemoServiceProvidesCompleteDeterministicInventory() async {
        let snapshot = await DockerService.demo().loadSnapshot()

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertTrue(snapshot.daemonAvailable)
        XCTAssertEqual(snapshot.containers.map(\.name), ["api-dev", "redis-dev"])
        XCTAssertEqual(snapshot.images.count, 2)
        XCTAssertEqual(snapshot.volumes.count, 2)
        XCTAssertEqual(snapshot.builderCache.entryCount, 34)
        XCTAssertEqual(snapshot.reclaimableBytes, 2_177_000_000)
        XCTAssertTrue(snapshot.warnings.isEmpty)
    }

    private static var dockerInventoryOutputs: [String: DockerService.CommandOutput] {
        [
            "version --format {{.Server.Version}}": .init(exitCode: 0, output: "26.1.0\n"),
            "info --format {{json .}}": .init(exitCode: 0, output: "{}\n"),
            "image ls --all --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"ID":"img1","Repository":"redis","Tag":"7","Size":"120MB","CreatedSince":"2 weeks ago"}"#
                    + "\n"
            ),
            "container ls --all --size --format {{json .}}": .init(
                exitCode: 0,
                output: containerJSON + "\n"
            ),
            "volume ls --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"Name":"redis-data","Driver":"local"}"# + "\n"
            ),
            "system df --format {{json .}}": .init(exitCode: 0, output: diskUsageSummary),
            "system df --verbose --format {{json .}}": .init(
                exitCode: 0,
                output: detailedDiskUsage
            ),
            "stats --no-stream --format {{json .}}": .init(
                exitCode: 0,
                output: statsJSON + "\n"
            )
        ]
    }

    private static var containerJSON: String {
        #"{"ID":"abc123","Names":"redis-dev","Image":"redis:7","State":"running","#
            + #""Status":"Up 2 hours","Ports":"6379/tcp","Size":"12MB (virtual 180MB)"}"#
    }

    private static var statsJSON: String {
        #"{"Container":"abc123","Name":"redis-dev","CPUPerc":"0.15%","#
            + #""MemUsage":"42MiB / 2GiB","MemPerc":"2.1%","NetIO":"1kB / 2kB","#
            + #""BlockIO":"3MB / 4MB","PIDs":"12"}"#
    }

    private static var diskUsageSummary: String {
        [
            #"{"Type":"Images","TotalCount":"1","Active":"1","Size":"100MB","Reclaimable":"40MB (40%)"}"#,
            #"{"Type":"Containers","TotalCount":"1","Active":"1","Size":"12MB","Reclaimable":"0B"}"#,
            #"{"Type":"Local Volumes","TotalCount":"1","Active":"1","Size":"7MB","Reclaimable":"2MB (28%)"}"#,
            #"{"Type":"Build Cache","TotalCount":"8","Active":"2","Size":"50MB","Reclaimable":"30MB"}"#
        ].joined(separator: "\n")
    }

    private static var detailedDiskUsage: String {
        #"{"Images":[{"ID":"img1","SharedSize":"40MB","UniqueSize":"80MB","Containers":"1"}],"#
            + #""Containers":[],"Volumes":[{"Name":"redis-data","Links":"0","Size":"7MB"}],"#
            + #""BuildCache":[]}"#
    }
}
