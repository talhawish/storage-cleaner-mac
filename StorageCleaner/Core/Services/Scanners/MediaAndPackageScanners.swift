import Foundation

struct NodeDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .nodeDependencies
    let title = StorageFindingKind.nodeDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .nodeDependencies,
            domain: .webDevelopment,
            paths: DependencyPaths.Node.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct PythonDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .pythonDependencies
    let title = StorageFindingKind.pythonDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .pythonDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.Python.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct RustDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .rustDependencies
    let title = StorageFindingKind.rustDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .rustDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.Rust.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct GoDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .goDependencies
    let title = StorageFindingKind.goDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .goDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.Go.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct PHPCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .phpDependencies
    let title = StorageFindingKind.phpDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .phpDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.PHP.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct RubyDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .rubyDependencies
    let title = StorageFindingKind.rubyDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .rubyDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.Ruby.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct DotNetCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .dotnetDependencies
    let title = StorageFindingKind.dotnetDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .dotnetDependencies,
            domain: .otherCaches,
            paths: DependencyPaths.DotNet.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct GradleCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .gradleDependencies
    let title = StorageFindingKind.gradleDependencies.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .gradleDependencies,
            domain: .mobileDevelopment,
            paths: DependencyPaths.Gradle.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct AIModelCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .aiModelCaches
    let title = StorageFindingKind.aiModelCaches.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .aiModelCaches,
            domain: .artificialIntelligence,
            paths: DependencyPaths.AI.cacheDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct LargeVideoScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .largeVideos
    let title = StorageFindingKind.largeVideos.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = [
            DependencyPaths.home("Movies"),
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop")
        ],
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .largeVideos,
            domain: .media,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased())
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct ScreenRecordingScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .screenRecordings
    let title = StorageFindingKind.screenRecordings.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = [
            DependencyPaths.home("Movies"),
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Downloads")
        ],
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .screenRecordings,
            domain: .media,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            guard DependencyPaths.Media.videoExtensions.contains(url.pathExtension.lowercased()) else { return false }
            let name = url.lastPathComponent.lowercased()
            return name.contains("screen recording") || name.contains("recording")
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct LargePhotoScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .largePhotos
    let title = StorageFindingKind.largePhotos.title
    private let scanner: FilePatternScanner

    init(
        roots: [URL] = [
            DependencyPaths.home("Pictures"),
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop")
        ],
        collector: FileSystemCollector
    ) {
        scanner = FilePatternScanner(
            kind: .largePhotos,
            domain: .photos,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            DependencyPaths.Media.imageExtensions.contains(url.pathExtension.lowercased())
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct DuplicatePhotoScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .duplicatePhotos
    let title = StorageFindingKind.duplicatePhotos.title
    private let scanner: DuplicateMediaScanner

    init(collector: FileSystemCollector) {
        let mediaRoots = [
            DependencyPaths.home("Pictures"),
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop")
        ]
        scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: mediaRoots,
            extensions: DependencyPaths.Media.imageExtensions,
            minimumBytes: 250_000,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct DuplicateVideoScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .duplicateVideos
    let title = StorageFindingKind.duplicateVideos.title
    private let scanner: DuplicateMediaScanner

    init(collector: FileSystemCollector) {
        let mediaRoots = [
            DependencyPaths.home("Movies"),
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop")
        ]
        scanner = DuplicateMediaScanner(
            kind: .duplicateVideos,
            domain: .media,
            roots: mediaRoots,
            extensions: DependencyPaths.Media.videoExtensions,
            minimumBytes: 5_000_000,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct JunkFileScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .junkFiles
    let title = StorageFindingKind.junkFiles.title
    private let scanner: FilePatternScanner

    init(collector: FileSystemCollector) {
        let junkRoots = [
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Library/Logs")
        ]
        scanner = FilePatternScanner(
            kind: .junkFiles,
            domain: .otherCaches,
            roots: junkRoots,
            safety: .review,
            collector: collector
        ) { url in
            let junkExtensions = ["tmp", "temp", "log", "crash"]
            return junkExtensions.contains(url.pathExtension.lowercased())
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
