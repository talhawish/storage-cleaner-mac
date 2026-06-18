struct AppContainer: Sendable {
    let storageScanner: any StorageScanning
    let permissionHandler: any StoragePermissionHandling

    static let live = AppContainer(
        storageScanner: LiveStorageScanner.live(),
        permissionHandler: FileSystemPermissionService()
    )

    static let uiTesting = AppContainer(
        storageScanner: DemoStorageScanner(stepDelay: .milliseconds(250)),
        permissionHandler: FileSystemPermissionService()
    )
}
