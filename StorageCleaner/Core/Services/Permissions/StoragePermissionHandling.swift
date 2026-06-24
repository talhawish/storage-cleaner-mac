protocol StoragePermissionHandling: Sendable {
    func currentStatuses() -> [StoragePermissionStatus]
    @MainActor
    func requestHomeFolderAccess() -> Bool
    func beginHomeFolderAccess() -> SecurityScopedResourceAccess?
}

extension StoragePermissionHandling {
    @MainActor
    func requestHomeFolderAccess() -> Bool {
        false
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        nil
    }
}
