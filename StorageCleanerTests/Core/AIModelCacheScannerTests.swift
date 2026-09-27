import Foundation
import XCTest
@testable import StorageCleaner

final class AIModelCacheScannerTests: XCTestCase {
    func testHubIncludesOnlyModelRepositoriesAndRejectsLinks() async throws {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let hub = root.appending(path: "hub")
        let model = hub.appending(path: "models--publisher--model")
        for directory in [model, hub.appending(path: "datasets--training"), hub.appending(path: "spaces--app")] {
            let blobs = directory.appending(path: "blobs")
            try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
            try Data(repeating: 1, count: 20_000).write(to: blobs.appending(path: "opaque-hash"))
        }
        try Data(repeating: 1, count: 20_000).write(to: root.appending(path: "token"))
        try FileManager.default.createSymbolicLink(
            at: hub.appending(path: "models--linked"), withDestinationURL: model
        )
        let result = await AIModelCacheScanner(
            collector: FileSystemCollector(), roots: [hub], repositoryRoots: [hub]
        ).scan()
        XCTAssertEqual(
            result.finding?.filePaths.map { $0.resolvingSymlinksInPath().path },
            [model.resolvingSymlinksInPath().path]
        )
        XCTAssertEqual(result.finding?.safety, .review)
    }

    func testDefaultLocationsAndQuickCleanExcludeAppDataAndCredentials() throws {
        let roots = DependencyPaths.ArtificialIntelligence.cacheDirs
        XCTAssertFalse(roots.contains(DependencyPaths.home("Library/Application Support/LM Studio")))
        XCTAssertFalse(roots.contains(DependencyPaths.home(".cache/huggingface")))
        XCTAssertTrue(roots.contains(DependencyPaths.home(".lmstudio/models")))
        let option = try XCTUnwrap(CleanupOptionsRegistry.allOptions.first { $0.storageKind == .aiModelCaches })
        XCTAssertEqual(option.paths, roots.map(\.path))
        XCTAssertEqual(option.safety, .review)
        XCTAssertFalse(option.isSafeByDefault)
    }
}
