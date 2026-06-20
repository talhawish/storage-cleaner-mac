import Foundation

struct LiveStorageScanner: StorageScanning {
    private let scanners: [any StorageCategoryScanning]

    init(scanners: [any StorageCategoryScanning]) {
        self.scanners = scanners
    }

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await scan(scanners: scanners(matching: kinds), to: continuation)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func scan(
        scanners activeScanners: [any StorageCategoryScanning],
        to continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        let scanStart = Date()
        let count = activeScanners.count
        guard count > 0 else {
            yieldEmptyCompleted(to: continuation)
            return
        }

        var progress = initialProgress(for: activeScanners)
        var findings: [StorageFinding?] = Array(repeating: nil, count: count)
        var inspectedCounts: [Int] = Array(repeating: 0, count: count)
        var completedCount = 0

        for index in 0..<count {
            progress[index] = progressItem(
                for: activeScanners[index],
                state: .scanning,
                message: "Scanning…"
            )
        }
        yieldProgress(0, count, 0, progress, continuation)

        await withTaskGroup(of: (Int, CategoryScanResult).self) { group in
            for (index, scanner) in activeScanners.enumerated() {
                group.addTask { [scanner] in
                    let result = await scanner.scan()
                    return (index, result)
                }
            }

            for await (index, result) in group {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }

                completedCount += 1
                findings[index] = result.finding
                inspectedCounts[index] = result.inspectedItemCount

                progress[index] = progressItem(
                    for: activeScanners[index],
                    state: result.finding == nil ? .skipped : .completed,
                    inspectedItemCount: result.inspectedItemCount,
                    message: result.message
                )

                let totalInspected = inspectedCounts.reduce(0, +)
                yieldProgress(completedCount, count, totalInspected, progress, continuation)
            }
        }

        guard !Task.isCancelled else { return }

        yieldCompleted(
            findings: findings.compactMap { $0 },
            scannedItemCount: inspectedCounts.reduce(0, +),
            startedAt: scanStart,
            to: continuation
        )
    }

    private func yieldEmptyCompleted(to continuation: AsyncStream<ScanEvent>.Continuation) {
        continuation.yield(
            .completed(
                ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(0))
            )
        )
    }

    private func initialProgress(for activeScanners: [any StorageCategoryScanning]) -> [ScannerProgress] {
        activeScanners.map { scanner in
            progressItem(for: scanner, state: .pending, message: "Waiting")
        }
    }

    private func scanners(matching kinds: Set<StorageFindingKind>?) -> [any StorageCategoryScanning] {
        guard let kinds, !kinds.isEmpty else { return scanners }
        return scanners.filter { kinds.contains($0.kind) }
    }

    private func progressItem(
        for scanner: any StorageCategoryScanning,
        state: ScannerProgressState,
        inspectedItemCount: Int = 0,
        message: String
    ) -> ScannerProgress {
        ScannerProgress(
            kind: scanner.kind,
            title: scanner.title,
            state: state,
            inspectedItemCount: inspectedItemCount,
            message: message
        )
    }

    private func yieldProgress(
        _ completedScannerCount: Int,
        _ totalScannerCount: Int,
        _ inspectedItemCount: Int,
        _ scannerProgress: [ScannerProgress],
        _ continuation: AsyncStream<ScanEvent>.Continuation
    ) {
        continuation.yield(
            .progress(
                fraction: fraction(
                    completedScannerCount: completedScannerCount,
                    totalScannerCount: totalScannerCount
                ),
                currentLocation: currentLocation(from: scannerProgress),
                scannedItemCount: inspectedItemCount,
                scannerProgress: scannerProgress
            )
        )
    }

    private func yieldCompleted(
        findings: [StorageFinding],
        scannedItemCount: Int,
        startedAt scanStart: Date,
        to continuation: AsyncStream<ScanEvent>.Continuation
    ) {
        continuation.yield(
            .completed(
                ScanSnapshot(
                    findings: findings,
                    scannedItemCount: scannedItemCount,
                    duration: .seconds(abs(scanStart.timeIntervalSinceNow))
                )
            )
        )
    }

    private func fraction(completedScannerCount: Int, totalScannerCount: Int) -> Double {
        guard totalScannerCount > 0 else { return 1 }
        return Double(completedScannerCount) / Double(totalScannerCount)
    }

    private func currentLocation(from progress: [ScannerProgress]) -> String {
        let scanning = progress.filter { $0.state == .scanning }
        if scanning.count > 1 {
            return "Scanning \(scanning.count) categories in parallel…"
        }
        return scanning.first?.title ?? "Finalizing scan…"
    }
}

extension LiveStorageScanner {
    static func live() -> LiveStorageScanner {
        let collector = FileSystemCollector()

        return LiveStorageScanner(
            scanners: [
                XcodeStorageScanner(collector: collector),
                DockerStorageScanner(collector: collector),
                FlutterStorageScanner(collector: collector),
                ReactNativeStorageScanner(collector: collector),
                AndroidStudioStorageScanner(collector: collector),
                AndroidPackageScanner(collector: collector),
                NodeDependencyScanner(collector: collector),
                PythonDependencyScanner(collector: collector),
                RustDependencyScanner(collector: collector),
                GoDependencyScanner(collector: collector),
                PHPDependencyScanner(collector: collector),
                RubyDependencyScanner(collector: collector),
                DotNetCacheScanner(collector: collector),
                GradleCacheScanner(collector: collector),
                AIModelCacheScanner(collector: collector),
                LargeFileScanner(collector: collector),
                LargeVideoScanner(collector: collector),
                ScreenRecordingScanner(collector: collector),
                LargePhotoScanner(collector: collector),
                DuplicatePhotoScanner(collector: collector),
                DuplicateVideoScanner(collector: collector),
                DuplicateDocumentScanner(collector: collector),
                ScreenshotStorageScanner(collector: collector),
                JunkFileScanner(collector: collector),
                LeftoversScanner(collector: collector),
                CLIAppScanner(collector: collector),
                RuntimeVersionScanner(),
                TrashStorageScanner(collector: collector)
            ]
        )
    }
}
