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
}
