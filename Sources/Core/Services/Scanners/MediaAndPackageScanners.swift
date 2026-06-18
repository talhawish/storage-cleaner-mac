import Foundation

struct NodeDependencyScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .nodeDependencies
    let title = StorageFindingKind.nodeDependencies.title
    private let scanner: PathListScanner

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .nodeDependencies,
            domain: .webDevelopment,
            paths: [
                paths.home(".npm"),
                paths.home("Library/pnpm/store"),
                paths.home(".yarn"),
                paths.home(".cache/yarn")
            ],
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct PackageArtifactScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .packageArtifacts
    let title = StorageFindingKind.packageArtifacts.title
    private let scanner: PathListScanner

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .packageArtifacts,
            domain: .otherCaches,
            paths: [
                paths.home(".gradle/caches"),
                paths.home(".m2/repository"),
                paths.home(".composer/cache"),
                paths.home("Library/Caches/pip"),
                paths.home("Library/Caches/pypoetry"),
                paths.home(".cargo/registry"),
                paths.home("go/pkg/mod"),
                paths.home(".nuget/packages")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .aiModelCaches,
            domain: .artificialIntelligence,
            paths: [
                paths.home(".ollama/models"),
                paths.home(".cache/huggingface"),
                paths.home("Library/Application Support/LM Studio"),
                paths.home("stable-diffusion-webui/models")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .largeVideos,
            domain: .media,
            roots: [paths.home("Movies"), paths.home("Downloads"), paths.home("Desktop")],
            safety: .review,
            collector: collector
        ) { url in
            let videoExtensions = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]
            return videoExtensions.contains(url.pathExtension.lowercased())
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .screenRecordings,
            domain: .media,
            roots: [paths.home("Movies"), paths.home("Desktop"), paths.home("Downloads")],
            safety: .review,
            collector: collector
        ) { url in
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .largePhotos,
            domain: .photos,
            roots: [paths.home("Pictures"), paths.home("Downloads"), paths.home("Desktop")],
            safety: .review,
            collector: collector
        ) { url in
            let photoExtensions = ["raw", "dng", "heic", "tiff", "tif", "png", "jpg", "jpeg"]
            return photoExtensions.contains(url.pathExtension.lowercased())
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = DuplicateMediaScanner(
            kind: .duplicatePhotos,
            domain: .photos,
            roots: [paths.home("Pictures"), paths.home("Downloads"), paths.home("Desktop")],
            extensions: ["heic", "png", "jpg", "jpeg", "tiff", "tif", "dng", "raw"],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = DuplicateMediaScanner(
            kind: .duplicateVideos,
            domain: .media,
            roots: [paths.home("Movies"), paths.home("Downloads"), paths.home("Desktop")],
            extensions: ["mov", "mp4", "m4v", "avi", "mkv", "webm"],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .junkFiles,
            domain: .otherCaches,
            roots: [paths.home("Downloads"), paths.home("Desktop"), paths.home("Library/Logs")],
            safety: .review,
            collector: collector
        ) { url in
            let junkExtensions = ["tmp", "temp", "log", "crash", "zip", "dmg"]
            return junkExtensions.contains(url.pathExtension.lowercased())
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
