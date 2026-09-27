import Foundation
import XCTest
@testable import StorageCleaner

final class HomeStorageDiscoveryTests: XCTestCase {
    private var temporaryHome: URL!

    override func setUpWithError() throws {
        temporaryHome = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryHome,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryHome)
    }

    func testFindsHiddenUnclassifiedFoldersAndModelWeightsInOneSharedWalk() async throws {
        let knownCache = temporaryHome.appending(path: ".cache/managed", directoryHint: .isDirectory)
        let knownModelStore = temporaryHome.appending(path: "known-model-store", directoryHint: .isDirectory)
        let hiddenData = temporaryHome.appending(path: ".unknown-data/nested", directoryHint: .isDirectory)
        let siblingCache = temporaryHome.appending(path: ".cache/other-tool", directoryHint: .isDirectory)
        let customModelFolder = temporaryHome.appending(path: "Custom Models", directoryHint: .isDirectory)

        try writeFile(in: knownCache, name: "cache.dat", bytes: 240_000)
        try writeFile(in: knownModelStore, name: "known.safetensors", bytes: 240_000)
        try writeFile(in: hiddenData, name: "opaque.bin", bytes: 320_000)
        try writeFile(in: siblingCache, name: "opaque.db", bytes: 280_000)
        try writeFile(in: customModelFolder, name: "weights.gguf", bytes: 360_000)
        try writeFile(in: customModelFolder, name: "notes.txt", bytes: 200_000)

        let policy = HomeStorageDiscoveryPolicy(
            root: temporaryHome,
            excludedFolderRoots: [knownCache, knownModelStore],
            excludedModelRoots: [knownModelStore],
            minimumFolderBytes: 100_000,
            minimumModelBytes: 100_000,
            maximumFolderCandidates: 20,
            maximumModelCandidates: 20
        )
        let cache = HomeStorageDiscoveryCache(policy: policy)
        async let folderScan = LargeFolderScanner(discoveryCache: cache).scan()
        async let modelScan = LocalAIModelScanner(discoveryCache: cache).scan()
        let (folderResult, modelResult) = await (folderScan, modelScan)

        let folderFinding = try XCTUnwrap(folderResult.finding)
        let modelFinding = try XCTUnwrap(modelResult.finding)
        XCTAssertEqual(folderFinding.safety, .review)
        XCTAssertEqual(folderFinding.domain, .otherCaches)
        XCTAssertEqual(modelFinding.safety, .review)
        XCTAssertEqual(modelFinding.domain, .artificialIntelligence)
        XCTAssertEqual(Set(folderFinding.filePaths.map(\.standardizedFileURL)), Set([
            temporaryHome.appending(path: ".unknown-data", directoryHint: .isDirectory).standardizedFileURL,
            siblingCache.standardizedFileURL
        ]))
        XCTAssertEqual(modelFinding.filePaths.map(\.lastPathComponent), ["weights.gguf"])
        XCTAssertGreaterThan(
            folderFinding.pathBytes[temporaryHome.appending(path: ".unknown-data", directoryHint: .isDirectory)] ?? 0,
            100_000
        )
        XCTAssertGreaterThan(folderResult.inspectedItemCount + modelResult.inspectedItemCount, 0)
        XCTAssertTrue(folderResult.inspectedItemCount == 0 || modelResult.inspectedItemCount == 0)
        XCTAssertFalse(folderFinding.filePaths.contains(knownCache))
        XCTAssertFalse(modelFinding.filePaths.contains(knownModelStore))
    }

    func testDoesNotPromoteSmallOrUnrecognizedItems() async throws {
        let data = temporaryHome.appending(path: ".small-data", directoryHint: .isDirectory)
        let models = temporaryHome.appending(path: "models", directoryHint: .isDirectory)
        let conversations = temporaryHome.appending(path: "conversations", directoryHint: .isDirectory)
        try writeFile(in: data, name: "small.dat", bytes: 5_000)
        try writeFile(in: models, name: "notes.txt", bytes: 500_000)
        try writeFile(in: models, name: "small.gguf", bytes: 5_000)
        try writeFile(in: conversations, name: "history.pb", bytes: 500_000)

        let cache = HomeStorageDiscoveryCache(policy: HomeStorageDiscoveryPolicy(
            root: temporaryHome,
            excludedFolderRoots: [],
            excludedModelRoots: [],
            minimumFolderBytes: 1_000_000,
            minimumModelBytes: 100_000,
            maximumFolderCandidates: 20,
            maximumModelCandidates: 20
        ))

        let folders = await LargeFolderScanner(discoveryCache: cache).scan()
        await cache.beginScan()
        let modelsResult = await LocalAIModelScanner(discoveryCache: cache).scan()

        XCTAssertNil(folders.finding)
        XCTAssertNil(modelsResult.finding)
    }

    func testRecognizedModelFilesStayInTheAISectionInsteadOfLargeFiles() async throws {
        let downloads = temporaryHome.appending(path: "Downloads", directoryHint: .isDirectory)
        try writeFile(in: downloads, name: "weights.gguf", bytes: 11_000_000)
        try writeFile(in: downloads, name: "dataset.dat", bytes: 11_200_000)

        let scanner = LargeFileScanner(
            roots: [downloads],
            minimumBytes: 100_000,
            modelDiscoveryPolicy: policy(),
            collector: FileSystemCollector()
        )
        let result = await scanner.scan()

        XCTAssertEqual(result.finding?.filePaths.map(\.lastPathComponent), ["dataset.dat"])
    }

    func testAmbiguousModelExtensionsNeedModelPathContext() throws {
        let defaultMinimum: Int64 = 100_000
        let conversation = temporaryHome.appending(path: "conversations/history.pb")
        let savedModel = temporaryHome.appending(path: "models/saved_model.pb")
        let binaryExport = temporaryHome.appending(path: "exports/archive.bin")
        let binaryWeights = temporaryHome.appending(path: "weights/model.bin")

        let conversationFormat = try XCTUnwrap(LocalAIModelFormat(url: conversation))
        let savedModelFormat = try XCTUnwrap(LocalAIModelFormat(url: savedModel))
        let binaryExportFormat = try XCTUnwrap(LocalAIModelFormat(url: binaryExport))
        let binaryWeightsFormat = try XCTUnwrap(LocalAIModelFormat(url: binaryWeights))

        XCTAssertFalse(conversationFormat.isLikelyModel(
            at: conversation,
            bytes: 500_000,
            defaultMinimum: defaultMinimum
        ))
        XCTAssertTrue(savedModelFormat.isLikelyModel(
            at: savedModel,
            bytes: 500_000,
            defaultMinimum: defaultMinimum
        ))
        XCTAssertFalse(binaryExportFormat.isLikelyModel(
            at: binaryExport,
            bytes: 1_100_000_000,
            defaultMinimum: defaultMinimum
        ))
        XCTAssertTrue(binaryWeightsFormat.isLikelyModel(
            at: binaryWeights,
            bytes: 1_100_000_000,
            defaultMinimum: defaultMinimum
        ))
    }

    func testLivePolicyLeavesSimulatorModelsToTheSimulatorCategory() {
        XCTAssertTrue(
            HomeStorageDiscoveryPolicy.live.excludedModelRoots.contains(
                DependencyPaths.Apple.coreSimulator
            )
        )
    }

    func testModelsOutsideHomeRemainDiscoverableAsLargeFiles() async throws {
        let volume = temporaryHome.appending(path: "ExternalVolume")
        let home = temporaryHome.appending(path: "Home")
        try writeFile(in: volume, name: "download.gguf", bytes: 11_000_000)
        let scanner = LargeFileScanner(
            roots: [volume],
            modelDiscoveryPolicy: policy(root: home),
            collector: FileSystemCollector()
        )
        let result = await scanner.scan()
        XCTAssertEqual(result.finding?.filePaths.map(\.lastPathComponent), ["download.gguf"])
    }

    func testOwnedTreesArePrunedButUnknownSiblingsAreScanned() async throws {
        let owned = temporaryHome.appending(path: ".cache/owned")
        let unknown = temporaryHome.appending(path: ".cache/custom")
        for index in 0..<20 {
            try writeFile(in: owned, name: "bundled-\(index).gguf", bytes: 200_000)
        }
        try writeFile(in: unknown, name: "custom.gguf", bytes: 300_000)
        let report = await HomeStorageDiscoveryCache(policy: policy(excludedModels: [owned])).discover()
        XCTAssertEqual(report.result.localAIModels.map(\.url.lastPathComponent), ["custom.gguf"])
        XCTAssertLessThan(report.inspectedItemCount, 10, "Owned trees must be skipped, not walked and filtered")
    }

    func testDeepFolderChainsDoNotCrowdIndependentFoldersOutOfCap() async throws {
        let deep = temporaryHome.appending(path: "large/one/two/three/four/five/six/seven/eight/nine")
        try writeFile(in: deep, name: "data.dat", bytes: 400_000)
        try writeFile(in: temporaryHome.appending(path: "independent"), name: "data.dat", bytes: 200_000)
        let report = await HomeStorageDiscoveryCache(policy: policy(maximumFolders: 2)).discover()
        XCTAssertEqual(report.result.largeFolders.map(\.url.lastPathComponent), ["large", "independent"])
    }

    func testUnreadableChildDoesNotProduceMisleadingParentSize() async throws {
        let parent = temporaryHome.appending(path: "partial")
        let blocked = parent.appending(path: "unreadable")
        try writeFile(in: parent, name: "visible.dat", bytes: 200_000)
        try writeFile(in: blocked, name: "secret.dat", bytes: 200_000)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: blocked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blocked.path) }
        let report = await HomeStorageDiscoveryCache(policy: policy()).discover()
        XCTAssertTrue(report.result.largeFolders.isEmpty)
        XCTAssertGreaterThan(report.result.unreadableItemCount, 0)
    }

    func testModelBundlesAreSingleReviewItemsAndSymlinksAreNotFollowed() async throws {
        let bundle = temporaryHome.appending(path: "models/example.mlmodelc")
        try writeFile(in: bundle, name: "weights.bin", bytes: 200_000)
        let link = temporaryHome.appending(path: "linked-models")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: bundle)
        let report = await HomeStorageDiscoveryCache(policy: policy()).discover()
        XCTAssertEqual(report.result.localAIModels.map(\.url.standardizedFileURL), [bundle.standardizedFileURL])
        XCTAssertTrue(report.result.largeFolders.isEmpty)
    }

    func testZeroCandidateLimitsReturnNoCandidates() async throws {
        try writeFile(in: temporaryHome.appending(path: "data"), name: "large.dat", bytes: 200_000)
        let report = await HomeStorageDiscoveryCache(policy: policy(maximumFolders: 0)).discover()
        XCTAssertTrue(report.result.largeFolders.isEmpty)
    }

    func testScanSessionsReadFreshDataAfterPriorStreamTerminates() async throws {
        let models = temporaryHome.appending(path: "models")
        try writeFile(in: models, name: "first.gguf", bytes: 200_000)
        let policy = policy()
        let scanner = LiveStorageScanner(scanners: [], sessionFactory: {
            let cache = HomeStorageDiscoveryCache(policy: policy)
            return LiveStorageScanner(
                scanners: [LocalAIModelScanner(discoveryCache: cache)],
                homeStorageDiscoveryCache: cache
            )
        })
        let first = await modelPaths(from: scanner)
        try writeFile(in: models, name: "second.gguf", bytes: 300_000)
        let second = await modelPaths(from: scanner)
        XCTAssertEqual(first, ["first.gguf"])
        XCTAssertEqual(second, ["second.gguf", "first.gguf"])
    }

    private func modelPaths(from scanner: LiveStorageScanner) async -> [String] {
        for await event in scanner.scanEvents(for: [.localAIModels]) {
            if case let .completed(snapshot) = event {
                return snapshot.findings.flatMap(\.filePaths).map(\.lastPathComponent)
            }
        }
        return []
    }

    private func policy(
        root: URL? = nil,
        excludedModels: [URL] = [],
        maximumFolders: Int = 20
    ) -> HomeStorageDiscoveryPolicy {
        HomeStorageDiscoveryPolicy(
            root: root ?? temporaryHome,
            excludedFolderRoots: [],
            excludedModelRoots: excludedModels,
            minimumFolderBytes: 100_000,
            minimumModelBytes: 100_000,
            maximumFolderCandidates: maximumFolders,
            maximumModelCandidates: 20
        )
    }

    private func writeFile(in directory: URL, name: String, bytes: Int) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        let data = Data(repeating: 0xA5, count: bytes)
        try data.write(to: url)
    }
}
