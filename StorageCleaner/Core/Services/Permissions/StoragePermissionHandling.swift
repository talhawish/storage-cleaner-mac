protocol StoragePermissionHandling: Sendable {
    func currentStatuses() -> [StoragePermissionStatus]
}
