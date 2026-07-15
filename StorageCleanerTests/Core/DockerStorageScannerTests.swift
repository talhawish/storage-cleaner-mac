import Foundation
import XCTest
@testable import StorageCleaner

final class DockerStorageScannerTests: XCTestCase {
    func testScanReportsOnlyDockerReclaimableBytes() async throws {
        let scanner = DockerStorageScanner(
            collector: FileSystemCollector(),
            dockerService: service(reclaimableImages: "40MB", reclaimableCache: "30MB")
        )

        let result = await scanner.scan()
        let finding = try XCTUnwrap(result.finding)

        XCTAssertEqual(finding.kind, .dockerArtifacts)
        XCTAssertEqual(finding.bytes, 70_000_000)
        XCTAssertEqual(finding.safety, .review)
        XCTAssertTrue(finding.filePaths.isEmpty)
    }

    func testRunningDockerWithNoReclaimableStorageDoesNotScanDesktopBackingFiles() async {
        let scanner = DockerStorageScanner(
            collector: FileSystemCollector(),
            dockerService: service(reclaimableImages: "0B", reclaimableCache: "0B")
        )

        let result = await scanner.scan()

        XCTAssertNil(result.finding)
        XCTAssertEqual(result.message, "Docker has no currently reclaimable storage")
    }

    func testUnavailableCanonicalUsageDoesNotReportAllInventoryAsReclaimable() async {
        let scanner = DockerStorageScanner(
            collector: FileSystemCollector(),
            dockerService: service(
                reclaimableImages: "40MB",
                reclaimableCache: "30MB",
                diskUsageSucceeds: false
            )
        )

        let result = await scanner.scan()

        XCTAssertNil(result.finding)
        XCTAssertEqual(result.message, "Docker reclaimable storage is temporarily unavailable")
    }

    private func service(
        reclaimableImages: String,
        reclaimableCache: String,
        diskUsageSucceeds: Bool = true
    ) -> DockerService {
        DockerService(
            locateDocker: { URL(fileURLWithPath: "/usr/local/bin/docker") },
            isDockerDesktopInstalled: { true },
            runCommand: { _, arguments in
                switch arguments.joined(separator: " ") {
                case "version --format {{.Server.Version}}":
                    .init(exitCode: 0, output: "26.1.0")
                case "info --format {{json .}}":
                    .init(exitCode: 0, output: "{}")
                case "system df --format {{json .}}":
                    .init(
                        exitCode: diskUsageSucceeds ? 0 : 1,
                        output: Self.diskUsage(
                            reclaimableImages: reclaimableImages,
                            reclaimableCache: reclaimableCache
                        )
                    )
                case "system df --verbose --format {{json .}}":
                    .init(
                        exitCode: 0,
                        output: #"{"Images":[],"Containers":[],"Volumes":[],"BuildCache":[]}"#
                    )
                default:
                    .init(exitCode: 0, output: "")
                }
            }
        )
    }

    private static func diskUsage(reclaimableImages: String, reclaimableCache: String) -> String {
        [
            #"{"Type":"Images","TotalCount":"2","Active":"1","Size":"100MB","Reclaimable":"\#(reclaimableImages)"}"#,
            #"{"Type":"Containers","TotalCount":"1","Active":"1","Size":"10MB","Reclaimable":"0B"}"#,
            #"{"Type":"Local Volumes","TotalCount":"1","Active":"1","Size":"20MB","Reclaimable":"0B"}"#,
            #"{"Type":"Build Cache","TotalCount":"3","Active":"0","Size":"50MB","Reclaimable":"\#(reclaimableCache)"}"#
        ].joined(separator: "\n")
    }
}
