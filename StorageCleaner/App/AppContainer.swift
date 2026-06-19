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
                let allFindings = [
                    StorageFinding(
                        kind: .xcodeArtifacts,
                        domain: .appleDevelopment,
                        bytes: 1_572_864_000,
                        itemCount: 3,
                        safety: .safe,
                        examples: ["DerivedData", "Archives", "SwiftPM"],
                        filePaths: [
                            URL(fileURLWithPath: "/tmp/StorageCleanerUITests/DerivedData"),
                            URL(fileURLWithPath: "/tmp/StorageCleanerUITests/Archives"),
                            URL(fileURLWithPath: "/tmp/StorageCleanerUITests/SwiftPM")
                        ]
                    )
                ]
                let findings = allFindings.filter { kinds?.contains($0.kind) ?? true }
                continuation.yield(
                    .completed(
                        ScanSnapshot(
                            findings: findings,
                            scannedItemCount: 3,
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
