protocol StorageScanning: Sendable {
    func scanEvents(for kinds: Set<StorageFindingKind>?) -> AsyncStream<ScanEvent>
}

extension StorageScanning {
    func scanEvents() -> AsyncStream<ScanEvent> {
        scanEvents(for: nil)
    }
}
