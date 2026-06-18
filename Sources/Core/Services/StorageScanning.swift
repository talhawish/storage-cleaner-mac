protocol StorageScanning: Sendable {
    func scanEvents() -> AsyncStream<ScanEvent>
}
