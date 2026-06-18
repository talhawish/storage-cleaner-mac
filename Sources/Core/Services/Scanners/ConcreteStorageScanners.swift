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
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .dockerArtifacts,
            domain: .containers,
            paths: DependencyPaths.Docker.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
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

    init(collector: FileSystemCollector) {
        let roots = [
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Developer")
        ]
        scanner = FilePatternScanner(
            kind: .androidPackages,
            domain: .mobileDevelopment,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            ["apk", "aab"].contains(url.pathExtension.lowercased())
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

    init(collector: FileSystemCollector) {
        let roots = [
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Pictures"),
            DependencyPaths.home("Downloads")
        ]
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
