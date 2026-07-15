import Foundation

struct LiveStorageScanner: StorageScanning {
    /// How many category scanners run at once. Each scanner performs blocking
    /// filesystem enumeration, so running all ~36 at once would thrash the
    /// disk and monopolize the cooperative thread pool; a small window keeps
    /// the disk busy without starving the rest of the app.
    static let maxConcurrentScanners = 6

    private let scanners: [any StorageCategoryScanning]
    /// Per-scan traversal memoization shared by the user-folder scanners.
    /// `nil` in tests that construct scanners directly.
    private let snapshotCache: DirectorySnapshotCache?

    init(scanners: [any StorageCategoryScanning], snapshotCache: DirectorySnapshotCache? = nil) {
        self.scanners = scanners
        self.snapshotCache = snapshotCache
    }

    func scanEvents(for kinds: Set<StorageFindingKind>? = nil) -> AsyncStream<ScanEvent> {
        AsyncStream { continuation in
            let task = Task { [snapshotCache] in
                // Fresh cache generation per scan so rescans re-read the disk.
                await snapshotCache?.beginScan()
                await scan(scanners: scanners(matching: kinds), to: continuation)
                await snapshotCache?.endScan()
                continuation.finish()
            }

            continuation.onTermination = { [snapshotCache] _ in
                task.cancel()
                // The cache's walks are detached tasks, not children of `task`,
                // so cancel them explicitly when the stream is torn down.
                if let snapshotCache {
                    Task { await snapshotCache.endScan() }
                }
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

        await runWindowedScan(
            scanners: activeScanners,
            progress: &progress,
            findings: &findings,
            inspectedCounts: &inspectedCounts,
            continuation: continuation
        )

        guard !Task.isCancelled else { return }

        yieldCompleted(
            findings: findings.compactMap { $0 },
            scannedItemCount: inspectedCounts.reduce(0, +),
            startedAt: scanStart,
            to: continuation
        )
    }

    /// Windowed execution: start at most `maxConcurrentScanners`, then launch
    /// the next scanner as each one finishes. Event semantics are unchanged —
    /// per-kind results still stream as they complete, and not-yet-started
    /// scanners keep their "Waiting" progress state.
    private func runWindowedScan(
        scanners activeScanners: [any StorageCategoryScanning],
        progress: inout [ScannerProgress],
        findings: inout [StorageFinding?],
        inspectedCounts: inout [Int],
        continuation: AsyncStream<ScanEvent>.Continuation
    ) async {
        let count = activeScanners.count
        var completedCount = 0

        await withTaskGroup(of: (Int, CategoryScanResult).self) { group in
            var pending = activeScanners.enumerated().makeIterator()
            func addNextScanner() {
                guard let (index, scanner) = pending.next() else { return }
                progress[index] = progressItem(
                    for: scanner,
                    state: .scanning,
                    message: "Scanning…"
                )
                group.addTask { [scanner] in
                    let result = await scanner.scan()
                    return (index, result)
                }
            }
            for _ in 0..<min(Self.maxConcurrentScanners, count) {
                addNextScanner()
            }
            yieldProgress(0, count, 0, progress, continuation)

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

                addNextScanner()
                let totalInspected = inspectedCounts.reduce(0, +)
                yieldProgress(completedCount, count, totalInspected, progress, continuation)
            }
        }
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
        live(dockerService: .live, permissionHandler: nil)
    }

    static func live(permissionHandler: (any StoragePermissionHandling)?) -> LiveStorageScanner {
        live(dockerService: .live, permissionHandler: permissionHandler)
    }

    static func live(
        dockerService: DockerService,
        permissionHandler: (any StoragePermissionHandling)? = nil
    ) -> LiveStorageScanner {
        let collector = FileSystemCollector()
        let appCatalog = LazyInstalledAppCatalog()
        // The scanners below share the user's home folders (Downloads, Desktop,
        // Documents, Movies, Pictures). `SnapshotTraversal` memoizes one walk
        // per root per scan instead of each of them re-enumerating the same
        // trees concurrently; scanners with unique roots keep the direct
        // collector, which walks without snapshot overhead.
        let snapshotCache = DirectorySnapshotCache()
        let shared = SnapshotTraversal(cache: snapshotCache)
        let scanners: [any StorageCategoryScanning] = [
            XcodeStorageScanner(collector: collector),
            IosDeviceSupportScanner(),
            DockerStorageScanner(collector: collector, dockerService: dockerService),
            FlutterStorageScanner(collector: collector),
            ReactNativeStorageScanner(collector: collector),
            AndroidStudioStorageScanner(collector: collector),
            AndroidPackageScanner(collector: shared),
            NodeDependencyScanner(collector: collector),
            PythonDependencyScanner(collector: collector),
            RustDependencyScanner(collector: collector),
            GoDependencyScanner(collector: collector),
            PHPDependencyScanner(collector: collector),
            RubyDependencyScanner(collector: collector),
            DotNetCacheScanner(collector: collector),
            GradleCacheScanner(collector: collector),
            AIModelCacheScanner(collector: collector),
            BrowserCacheScanner(collector: collector),
            LargeFileScanner(collector: shared),
            LargeVideoScanner(collector: shared),
            ScreenRecordingScanner(collector: shared),
            LargePhotoScanner(collector: shared),
            DuplicatePhotoScanner(collector: shared, snapshotCache: snapshotCache),
            DuplicateVideoScanner(collector: shared, snapshotCache: snapshotCache),
            DuplicateDocumentScanner(collector: shared, snapshotCache: snapshotCache),
            ScreenshotStorageScanner(collector: shared),
            JunkFileScanner(collector: shared),
            LeftoversScanner(collector: shared),
            CLIAppScanner(collector: collector),
            RuntimeVersionScanner(),
            OrphanedAppSupportScanner(collector: collector, catalog: appCatalog),
            OrphanedAppCachesScanner(collector: collector, catalog: appCatalog),
            OrphanedAppContainersScanner(collector: collector, catalog: appCatalog),
            OrphanedPreferencesScanner(catalog: appCatalog, collector: collector),
            OrphanedSavedAppStateScanner(collector: collector, catalog: appCatalog),
            OldCrashReportsScanner(collector: collector),
            TrashStorageScanner(collector: collector)
        ]

        let scopedScanners = permissionHandler.map { handler in
            scanners.map { SecurityScopedCategoryScanner(scanner: $0, permissionHandler: handler) }
        } ?? scanners

        return LiveStorageScanner(
            scanners: scopedScanners,
            snapshotCache: snapshotCache
        )
    }
}
