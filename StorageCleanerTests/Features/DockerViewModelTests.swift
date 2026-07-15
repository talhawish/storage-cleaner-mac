import Foundation
import XCTest
@testable import StorageCleaner

@MainActor
final class DockerViewModelTests: XCTestCase {
    func testSuccessfulImageRemovalReloadsInventoryAndMeasuresReclaimedBytes() async throws {
        let stub = DockerCommandStub()
        let viewModel = DockerViewModel(service: stub.service)
        viewModel.startLoading()
        await waitForLoading(viewModel)
        let image = try XCTUnwrap(viewModel.snapshot?.images.first)

        let outcome = await viewModel.perform(.removeImage(image))

        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.cleanup, DockerCleanupEvent(bytesReclaimed: 80_000_000, itemCount: 1))
        XCTAssertTrue(viewModel.snapshot?.images.isEmpty ?? false)
        XCTAssertEqual(viewModel.snapshot?.totalBytes, 20_000_000)
        XCTAssertEqual(viewModel.actionResult?.message, "Image removed.")
    }

    func testFailedRemovalKeepsInventoryAndSurfacesDockerError() async throws {
        let stub = DockerCommandStub(removalFails: true)
        let viewModel = DockerViewModel(service: stub.service)
        viewModel.startLoading()
        await waitForLoading(viewModel)
        let image = try XCTUnwrap(viewModel.snapshot?.images.first)

        let outcome = await viewModel.perform(.removeImage(image))

        XCTAssertFalse(outcome.succeeded)
        XCTAssertNil(outcome.cleanup)
        XCTAssertEqual(viewModel.snapshot?.images.count, 1)
        XCTAssertEqual(viewModel.actionResult?.message, "image is used by a container")
    }

    func testCancelLeavesLoadedSnapshotVisible() async {
        let stub = DockerCommandStub()
        let viewModel = DockerViewModel(service: stub.service)
        viewModel.startLoading()
        await waitForLoading(viewModel)

        viewModel.startLoading()
        viewModel.cancelLoading()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.snapshot)
    }

    func testBuilderPruneAuditCountsEveryRemovedCacheEntry() {
        let cache = DockerBuilderCache(bytes: 300, entryCount: 12, reclaimableBytes: 200)

        XCTAssertEqual(PendingDockerAction.pruneBuilderCache(cache).cleanupItemCount, 12)
    }

    private func waitForLoading(_ viewModel: DockerViewModel) async {
        for _ in 0..<200 where viewModel.isLoading {
            await Task.yield()
        }
    }
}

private actor DockerCommandStub {
    private var removed = false
    private let removalFails: Bool

    init(removalFails: Bool = false) {
        self.removalFails = removalFails
    }

    nonisolated var service: DockerService {
        DockerService(
            locateDocker: { URL(fileURLWithPath: "/usr/local/bin/docker") },
            isDockerDesktopInstalled: { true },
            runCommand: { [weak self] _, arguments in
                guard let self else { return .init(exitCode: 1, output: "Test stub released") }
                return await self.run(arguments)
            }
        )
    }

    private func run(_ arguments: [String]) -> DockerService.CommandOutput {
        switch arguments.joined(separator: " ") {
        case "version --format {{.Server.Version}}":
            .init(exitCode: 0, output: "26.1.0")
        case "info --format {{json .}}":
            .init(exitCode: 0, output: "{}")
        case "image ls --all --format {{json .}}":
            if removed {
                .init(exitCode: 0, output: "")
            } else {
                .init(
                    exitCode: 0,
                    output: #"{"ID":"img1","Repository":"demo","Tag":"latest","Size":"100MB"}"#
                )
            }
        case "image rm img1":
            removeImage()
        case "system df --format {{json .}}":
            .init(exitCode: 0, output: diskUsage)
        case "system df --verbose --format {{json .}}":
            .init(exitCode: 0, output: detailedDiskUsage)
        default:
            .init(exitCode: 0, output: "")
        }
    }

    private func removeImage() -> DockerService.CommandOutput {
        guard !removalFails else {
            return .init(exitCode: 1, output: "image is used by a container")
        }
        removed = true
        return .init(exitCode: 0, output: "img1")
    }

    private var diskUsage: String {
        let imageSize = removed ? "20MB" : "100MB"
        return [
            #"{"Type":"Images","TotalCount":"1","Active":"0","Size":"\#(imageSize)","Reclaimable":"\#(imageSize)"}"#,
            #"{"Type":"Containers","TotalCount":"0","Active":"0","Size":"0B","Reclaimable":"0B"}"#,
            #"{"Type":"Local Volumes","TotalCount":"0","Active":"0","Size":"0B","Reclaimable":"0B"}"#,
            #"{"Type":"Build Cache","TotalCount":"0","Active":"0","Size":"0B","Reclaimable":"0B"}"#
        ].joined(separator: "\n")
    }

    private var detailedDiskUsage: String {
        let images = removed
            ? "[]"
            : #"[{"ID":"img1","SharedSize":"20MB","UniqueSize":"80MB","Containers":"0"}]"#
        return #"{"Images":\#(images),"Containers":[],"Volumes":[],"BuildCache":[]}"#
    }
}
