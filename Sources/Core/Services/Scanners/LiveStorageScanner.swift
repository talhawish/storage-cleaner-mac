import Foundation

struct LiveStorageScanner: StorageScanning {
    private let scanners: [any StorageCategoryScanning]

    init(scanners: [any StorageCategoryScanning]) {
        self.scanners = scanners
    }

    func scanEvents() -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task {
                await scan(to: continuation)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func scan(to continuation: AsyncStream<ScanEvent>.Continuation) async {
        let count = scanners.count
        guard count > 0 else {
            yieldEmptyCompleted(to: continuation)
            return
        }

        var progress = initialProgress()
        var findings: [StorageFinding?] = Array(repeating: nil, count: count)
        var inspectedCounts: [Int] = Array(repeating: 0, count: count)
        var completedCount = 0

        for index in 0..<count {
            progress[index] = progressItem(for: scanners[index], state: .scanning, message: "Scanning…")
        }
        yieldProgress(0, 0, progress, continuation)

        await withTaskGroup(of: (Int, CategoryScanResult).self) { group in
            for (index, scanner) in scanners.enumerated() {
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
                    for: scanners[index],
                    state: result.finding == nil ? .skipped : .completed,
                    inspectedItemCount: result.inspectedItemCount,
                    message: result.message
                )

                let totalInspected = inspectedCounts.reduce(0, +)
                yieldProgress(completedCount, totalInspected, progress, continuation)
            }
        }

        guard !Task.isCancelled else { return }

        let completedFindings = findings.compactMap { $0 }
        let totalInspected = inspectedCounts.reduce(0, +)

        continuation.yield(
            .completed(
                ScanSnapshot(
                    findings: completedFindings,
                    scannedItemCount: totalInspected,
                    duration: .seconds(2)
                )
            )
        )
    }

    private func yieldEmptyCompleted(to continuation: AsyncStream<ScanEvent>.Continuation) {
        continuation.yield(
            .completed(
                ScanSnapshot(findings: [], scannedItemCount: 0, duration: .seconds(0))
            )
        )
    }

    private func initialProgress() -> [ScannerProgress] {
        scanners.map { scanner in
            progressItem(for: scanner, state: .pending, message: "Waiting")
        }
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
        _ inspectedItemCount: Int,
        _ scannerProgress: [ScannerProgress],
        _ continuation: AsyncStream<ScanEvent>.Continuation
    ) {
        continuation.yield(
            .progress(
                fraction: fraction(for: completedScannerCount),
                currentLocation: currentLocation(from: scannerProgress),
                scannedItemCount: inspectedItemCount,
                scannerProgress: scannerProgress
            )
        )
    }

    private func fraction(for completedScannerCount: Int) -> Double {
        guard !scanners.isEmpty else { return 1 }
        return Double(completedScannerCount) / Double(scanners.count)
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
        let paths = PathBuilder()
        let collector = FileSystemCollector()

        return LiveStorageScanner(
            scanners: [
                XcodeStorageScanner(paths: paths, collector: collector),
                DockerStorageScanner(paths: paths, collector: collector),
                FlutterStorageScanner(paths: paths, collector: collector),
                AndroidStudioStorageScanner(paths: paths, collector: collector),
                AndroidPackageScanner(paths: paths, collector: collector),
                NodeDependencyScanner(paths: paths, collector: collector),
                PackageArtifactScanner(paths: paths, collector: collector),
                BrowserCacheScanner(paths: paths, collector: collector),
                AIModelCacheScanner(paths: paths, collector: collector),
                LargeVideoScanner(paths: paths, collector: collector),
                ScreenRecordingScanner(paths: paths, collector: collector),
                LargePhotoScanner(paths: paths, collector: collector),
                DuplicatePhotoScanner(paths: paths, collector: collector),
                DuplicateVideoScanner(paths: paths, collector: collector),
                ScreenshotStorageScanner(paths: paths, collector: collector),
                JunkFileScanner(paths: paths, collector: collector),
                CLIAppScanner(paths: paths, collector: collector),
                TrashStorageScanner(paths: paths, collector: collector)
            ]
        )
    }
}
