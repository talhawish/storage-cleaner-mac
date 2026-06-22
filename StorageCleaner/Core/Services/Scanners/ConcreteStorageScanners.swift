import Foundation

struct XcodeStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .xcodeArtifacts
    let title = StorageFindingKind.xcodeArtifacts.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .xcodeArtifacts,
            domain: .appleDevelopment,
            paths: [
                DependencyPaths.Apple.derivedData,
                DependencyPaths.Apple.archives,
                DependencyPaths.Apple.coreSimulator,
                DependencyPaths.Apple.swiftPM
            ],
            safety: .safe,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct DockerStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .dockerArtifacts
    let title = StorageFindingKind.dockerArtifacts.title
    private let dockerService: DockerService
    private let fallbackScanner: PathListScanner

    init(collector: FileSystemCollector, dockerService: DockerService = .live) {
        self.dockerService = dockerService
        fallbackScanner = PathListScanner(
            kind: .dockerArtifacts,
            domain: .containers,
            paths: DependencyPaths.Docker.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        let snapshot = await dockerService.loadSnapshot()
        if snapshot.daemonAvailable, snapshot.totalBytes > 0 {
            return CategoryScanResult(
                finding: StorageFinding(
                    kind: .dockerArtifacts,
                    domain: .containers,
                    bytes: snapshot.totalBytes,
                    itemCount: max(snapshot.itemCount, 1),
                    safety: .review,
                    examples: snapshot.overviewExamples,
                    filePaths: []
                ),
                inspectedItemCount: snapshot.itemCount,
                message: "Measured Docker images, containers, volumes, and builder cache"
            )
        }

        return await fallbackScanner.scan()
    }
}

struct FlutterStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .flutterArtifacts
    let title = StorageFindingKind.flutterArtifacts.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .flutterArtifacts,
            domain: .mobileDevelopment,
            paths: DependencyPaths.Flutter.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct AndroidStudioStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .androidStudioArtifacts
    let title = StorageFindingKind.androidStudioArtifacts.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .androidStudioArtifacts,
            domain: .mobileDevelopment,
            paths: DependencyPaths.Android.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct AndroidPackageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .androidPackages
    let title = StorageFindingKind.androidPackages.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = ScanPreferences.includingExternalVolumes([
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Documents"),
            DependencyPaths.home("Developer")
        ]),
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .androidPackages,
            domain: .mobileDevelopment,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            DependencyPaths.Leftovers.androidPackageExtensions.contains(url.pathExtension.lowercased())
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct ScreenshotStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .screenshots
    let title = StorageFindingKind.screenshots.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = ScanPreferences.includingExternalVolumes([
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Pictures"),
            DependencyPaths.home("Downloads")
        ]),
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .screenshots,
            domain: .screenshots,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            guard DependencyPaths.Media.imageExtensions.contains(url.pathExtension.lowercased()) else { return false }
            let name = url.lastPathComponent.lowercased()
            return name.contains("screenshot") || name.contains("screen shot") || name.contains("simulator screen shot")
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct BrowserCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .browserCaches
    let title = StorageFindingKind.browserCaches.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .browserCaches,
            domain: .browserData,
            paths: DependencyPaths.Browser.cacheDirs,
            safety: .safe,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct TrashStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .trash
    let title = StorageFindingKind.trash.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .trash,
            domain: .trash,
            paths: [DependencyPaths.home(".Trash")],
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
