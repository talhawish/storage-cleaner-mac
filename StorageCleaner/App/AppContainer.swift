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
        demo(.largeVideos, .media, bytes: 3_758_096_384, items: 9, safety: .review),
        demo(.browserCaches, .browserData, bytes: 1_503_238_553, items: 64, safety: .safe),
        demo(.screenshots, .screenshots, bytes: 734_003_200, items: 218, safety: .review),
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
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 8, execute: complete)
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
    func delete(urls: [URL]) async -> CleanupResult {
        CleanupResult(
            deletedURLs: urls,
            deletedItems: urls.map { DeletedItem(originalURL: $0, bytesReclaimed: 0) },
            failedURLs: [],
            totalBytesReclaimed: 0
        )
    }
}
