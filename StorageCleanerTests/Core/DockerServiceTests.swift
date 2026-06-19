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
        let outputs: [String: DockerService.CommandOutput] = [
            "version --format {{.Server.Version}}": .init(exitCode: 0, output: "26.1.0\n"),
            "info --format {{json .}}": .init(exitCode: 0, output: "{}\n"),
            "image ls --all --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"ID":"img1","Repository":"redis","Tag":"7","Size":"120MB","CreatedSince":"2 weeks ago"}"#
                    + "\n"
            ),
            "container ls --all --size --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"ID":"abc123","Names":"redis-dev","Image":"redis:7","State":"running","Status":"Up 2 hours","Ports":"6379/tcp","Size":"12MB (virtual 180MB)"}"#
                    + "\n"
            ),
            "volume ls --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"Name":"redis-data","Driver":"local"}"# + "\n"
            ),
            "volume inspect redis-data --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"Mountpoint":"/tmp/redis-data"}"# + "\n"
            ),
            "builder du --verbose --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"Size":"50MB"}"# + "\n" + #"{"Size":"25MB"}"# + "\n"
            ),
            "stats --no-stream --format {{json .}}": .init(
                exitCode: 0,
                output: #"{"Container":"abc123","Name":"redis-dev","CPUPerc":"0.15%","MemUsage":"42MiB / 2GiB","MemPerc":"2.1%","NetIO":"1kB / 2kB","BlockIO":"3MB / 4MB","PIDs":"12"}"#
                    + "\n"
            )
        ]

        let service = DockerService(
            locateDocker: { docker },
            isDockerDesktopInstalled: { true },
            runCommand: { _, arguments in
                outputs[arguments.joined(separator: " ")] ?? .init(exitCode: 1, output: "missing")
            },
            measure: { _ in 7_000_000 }
        )

        let snapshot = await service.loadSnapshot()

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertTrue(snapshot.daemonAvailable)
        XCTAssertEqual(snapshot.version, "26.1.0")
        XCTAssertEqual(snapshot.images.count, 1)
        XCTAssertEqual(snapshot.containers.count, 1)
        XCTAssertEqual(snapshot.volumes.count, 1)
        XCTAssertEqual(snapshot.stats.count, 1)
        XCTAssertEqual(snapshot.builderCache.entryCount, 2)
        XCTAssertEqual(snapshot.totalBytes, 214_000_000)
    }

    func testSnapshotReportsInstalledWhenDesktopExistsButCLIIsMissing() async {
        let service = DockerService(
            locateDocker: { nil },
            isDockerDesktopInstalled: { true },
            runCommand: { _, _ in .init(exitCode: 1, output: "") },
            measure: { _ in 0 }
        )

        let snapshot = await service.loadSnapshot()

        XCTAssertTrue(snapshot.isInstalled)
        XCTAssertFalse(snapshot.daemonAvailable)
    }
}
