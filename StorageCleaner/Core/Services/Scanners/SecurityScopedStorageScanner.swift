import Foundation

struct SecurityScopedStorageScanner: StorageScanning {
    private let scanner: any StorageScanning
    private let permissionHandler: any StoragePermissionHandling

    init(scanner: any StorageScanning, permissionHandler: any StoragePermissionHandling) {
        self.scanner = scanner
        self.permissionHandler = permissionHandler
    }

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                guard let access = permissionHandler.beginHomeFolderAccess() else {
                    continuation.yield(
                        .failed(message: "Home Folder access is required before scanning.")
                    )
                    continuation.finish()
                    return
                }

                defer {
                    access.stop()
                    continuation.finish()
                }

                for await event in scanner.scanEvents(for: kinds) {
                    guard !Task.isCancelled else { return }
                    continuation.yield(event)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
