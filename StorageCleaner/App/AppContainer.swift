import Foundation

struct AppContainer: Sendable {
    let storageScanner: any StorageScanning
    let permissionHandler: any StoragePermissionHandling
    let cleanupService: CleanupService

    static let live = AppContainer(
        storageScanner: LiveStorageScanner.live(),
        permissionHandler: FileSystemPermissionService(),
        cleanupService: FileManagerCleanupService()
    )

    static func current(arguments: [String] = CommandLine.arguments) -> AppContainer {
        if arguments.contains("--use-demo-scanner") {
            return AppContainer(
                storageScanner: DemoStorageScanner(
                    completesImmediately: arguments.contains("--complete-demo-scan-immediately")
                ),
                permissionHandler: DemoPermissionHandler(),
                cleanupService: DemoCleanupService()
            )
        }

        return .live
    }
}

private struct DemoStorageScanner: StorageScanning {
    let completesImmediately: Bool

    /// Demo inventory spanning several domains and both safety levels so the redesigned Overview
    /// shows a populated breakdown grid, grouped detection rows, and tips.
    static let allFindings: [StorageFinding] = [
        demo(.xcodeArtifacts, .appleDevelopment, bytes: 18_535_280_640, items: 412, safety: .safe),
        demo(.nodeDependencies, .webDevelopment, bytes: 9_126_805_504, items: 286, safety: .safe),
        demo(.dockerArtifacts, .containers, bytes: 6_442_450_944, items: 37, safety: .safe),
        demo(.aiModelCaches, .artificialIntelligence, bytes: 4_294_967_296, items: 12, safety: .safe),
        demo(.flutterArtifacts, .mobileDevelopment, bytes: 2_813_624_320, items: 58, safety: .safe),
        demo(.reactNativeArtifacts, .mobileDevelopment, bytes: 2_469_396_480, items: 43, safety: .safe),
        demo(.androidStudioArtifacts, .mobileDevelopment, bytes: 3_221_225_472, items: 29, safety: .safe),
        demo(.pythonDependencies, .otherCaches, bytes: 2_040_109_056, items: 91, safety: .safe),
        demo(.rustDependencies, .otherCaches, bytes: 1_288_490_188, items: 76, safety: .safe),
        demo(.goDependencies, .otherCaches, bytes: 947_912_704, items: 44, safety: .safe),
        demo(.phpDependencies, .otherCaches, bytes: 1_395_864_576, items: 52, safety: .safe),
        demo(.rubyDependencies, .otherCaches, bytes: 1_019_215_872, items: 35, safety: .safe),
        demo(.dotnetDependencies, .otherCaches, bytes: 1_610_612_736, items: 61, safety: .safe),
        demo(.gradleDependencies, .otherCaches, bytes: 2_362_556_416, items: 80, safety: .safe),
        demo(.cliApps, .cliTooling, bytes: 3_006_906_368, items: 22, safety: .review),
        demo(.runtimeVersions, .cliTooling, bytes: 4_831_838_208, items: 11, safety: .review),
        demo(.largeFiles, .otherCaches, bytes: 5_368_709_120, items: 14, safety: .review),
        demo(.largeVideos, .media, bytes: 3_758_096_384, items: 9, safety: .review),
        demo(.largePhotos, .photos, bytes: 1_127_428_096, items: 27, safety: .review),
        demoDuplicate(.duplicatePhotos, .photos, bytes: 644_245_094, itemName: "duplicate-photo"),
        demoDuplicate(.duplicateVideos, .media, bytes: 1_932_735_283, itemName: "duplicate-video"),
        demoDuplicate(.duplicateDocuments, .documents, bytes: 214_748_365, itemName: "duplicate-document"),
        demo(.browserCaches, .browserData, bytes: 1_503_238_553, items: 64, safety: .safe),
        demo(.screenshots, .screenshots, bytes: 734_003_200, items: 218, safety: .review),
        demo(.screenRecordings, .media, bytes: 2_255_841_280, items: 6, safety: .review),
        demo(.junkFiles, .otherCaches, bytes: 185_597_952, items: 141, safety: .review),
        demo(.installerLeftovers, .documents, bytes: 2_684_354_560, items: 8, safety: .review),
        demo(.androidPackages, .mobileDevelopment, bytes: 912_680_550, items: 16, safety: .review),
        demo(.orphanedAppSupport, .systemJunk, bytes: 2_146_435_072, items: 47, safety: .review),
        demo(.orphanedAppCaches, .systemJunk, bytes: 1_073_741_824, items: 39, safety: .review),
        demo(.orphanedAppContainers, .systemJunk, bytes: 412_316_860, items: 18, safety: .review),
        demo(.orphanedAppPreferences, .systemJunk, bytes: 8_388_608, items: 124, safety: .review),
        demo(.oldCrashReports, .systemJunk, bytes: 24_117_248, items: 33, safety: .review),
        demo(.trash, .trash, bytes: 524_288_000, items: 96, safety: .review)
    ]

    private static func demo(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        items: Int,
        safety: CleanupSafety
    ) -> StorageFinding {
        let examples = Array(kind.summary.split(separator: ", ").prefix(3).map(String.init))
        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: bytes,
            itemCount: items,
            safety: safety,
            examples: examples,
            filePaths: examples.map { URL(fileURLWithPath: "/tmp/StorageCleanerDemo/\(kind.rawValue)/\($0)") }
        )
    }

    private static func demoDuplicate(
        _ kind: StorageFindingKind,
        _ domain: StorageDomain,
        bytes: Int64,
        itemName: String
    ) -> StorageFinding {
        let root = URL(fileURLWithPath: "/tmp/StorageCleanerDemo/\(kind.rawValue)", isDirectory: true)
        let modifiedAt = Date(timeIntervalSinceNow: -86_400)
        let files = [
            DuplicateFile(
                url: root.appendingPathComponent("\(itemName)-original.dat"),
                bytes: bytes,
                modifiedAt: modifiedAt
            ),
            DuplicateFile(
                url: root.appendingPathComponent("\(itemName)-copy-a.dat"),
                bytes: bytes,
                modifiedAt: modifiedAt
            ),
            DuplicateFile(
                url: root.appendingPathComponent("\(itemName)-copy-b.dat"),
                bytes: bytes,
                modifiedAt: modifiedAt
            )
        ]
        let group = DuplicateGroup(contentHash: "demo-\(kind.rawValue)", files: files, keepURL: files[0].url)
        let removable = group.removableURLs
        return StorageFinding(
            kind: kind,
            domain: domain,
            bytes: group.reclaimableBytes,
            itemCount: removable.count,
            safety: .review,
            examples: removable.map { $0.lastPathComponent },
            filePaths: removable,
            duplicateGroups: [group]
        )
    }

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let progress = ScannerProgress(
                kind: .xcodeArtifacts,
                title: StorageFindingKind.xcodeArtifacts.title,
                state: .scanning,
                inspectedItemCount: 0,
                message: "Scanning demo data"
            )
            continuation.yield(
                .progress(
                    fraction: 0.25,
                    currentLocation: "Scanning demo developer caches",
                    scannedItemCount: 1,
                    scannerProgress: [progress]
                )
            )

            let complete: @Sendable () -> Void = {
                let findings = DemoStorageScanner.allFindings.filter { kinds?.contains($0.kind) ?? true }
                continuation.yield(
                    .completed(
                        ScanSnapshot(
                            findings: findings,
                            scannedItemCount: 1_284,
                            duration: .seconds(4)
                        )
                    )
                )
                continuation.finish()
            }

            if completesImmediately {
                complete()
            } else {
                let task = Task {
                    try? await Task.sleep(for: .seconds(8))
                    guard !Task.isCancelled else { return }
                    complete()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }
}

private struct DemoPermissionHandler: StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] {
        StoragePermissionScope.allCases.map { scope in
            StoragePermissionStatus(
                scope: scope,
                url: FileManager.default.homeDirectoryForCurrentUser,
                state: .accessible
            )
        }
    }
}

private struct DemoCleanupService: CleanupService {
    private static let bytesByURL: [URL: Int64] = Dictionary(
        uniqueKeysWithValues: DemoStorageScanner.allFindings.flatMap { finding in
            finding.filePaths.map { ($0, demoBytes(for: $0, in: finding)) }
        }
    )

    func delete(urls: [URL]) async -> CleanupResult {
        let items = urls.map { url in
            DeletedItem(originalURL: url, bytesReclaimed: Self.bytesByURL[url] ?? 0)
        }
        return CleanupResult(
            deletedURLs: urls,
            deletedItems: items,
            failedURLs: [],
            totalBytesReclaimed: items.reduce(Int64(0)) { $0 + $1.bytesReclaimed }
        )
    }

    private static func demoBytes(for url: URL, in finding: StorageFinding) -> Int64 {
        if let duplicateFile = finding.duplicateGroups
            .flatMap(\.files)
            .first(where: { $0.url == url }) {
            return duplicateFile.bytes
        }
        return finding.itemCount > 0 ? finding.bytes / Int64(finding.itemCount) : finding.bytes
    }
}
