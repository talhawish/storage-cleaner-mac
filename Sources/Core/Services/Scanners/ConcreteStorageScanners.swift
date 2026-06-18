import Foundation

struct XcodeStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .xcodeArtifacts
    let title = StorageFindingKind.xcodeArtifacts.title
    private let scanner: PathListScanner

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .xcodeArtifacts,
            domain: .appleDevelopment,
            paths: [
                paths.home("Library/Developer/Xcode/DerivedData"),
                paths.home("Library/Developer/Xcode/Archives"),
                paths.home("Library/Developer/CoreSimulator"),
                paths.home("Library/Caches/org.swift.swiftpm")
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .dockerArtifacts,
            domain: .containers,
            paths: [
                paths.home("Library/Containers/com.docker.docker"),
                paths.home(".docker"),
                paths.home(".colima"),
                paths.home("Library/Application Support/OrbStack")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .flutterArtifacts,
            domain: .mobileDevelopment,
            paths: [
                paths.home(".pub-cache"),
                paths.home("Library/Caches/flutter"),
                paths.home("Developer/flutter")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .androidStudioArtifacts,
            domain: .mobileDevelopment,
            paths: [
                paths.home("Library/Android/sdk"),
                paths.home("Library/Android/sdk/system-images"),
                paths.home(".android/avd"),
                paths.home("Library/Caches/Google/AndroidStudio"),
                paths.home(".gradle/caches")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .androidPackages,
            domain: .mobileDevelopment,
            roots: [paths.home("Downloads"), paths.home("Desktop"), paths.home("Developer")],
            safety: .review,
            collector: collector
        ) { url in
            ["apk", "aab", "ipa"].contains(url.pathExtension.lowercased())
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = FilePatternScanner(
            kind: .screenshots,
            domain: .screenshots,
            roots: [paths.home("Desktop"), paths.home("Pictures"), paths.home("Downloads")],
            safety: .review,
            collector: collector
        ) { url in
            let name = url.lastPathComponent.lowercased()
            return name.contains("screenshot") || name.contains("screen shot")
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .browserCaches,
            domain: .browserData,
            paths: [
                paths.home("Library/Caches/com.apple.Safari"),
                paths.home("Library/Caches/Google/Chrome"),
                paths.home("Library/Caches/Microsoft Edge"),
                paths.home("Library/Caches/Firefox"),
                paths.home("Library/Caches/company.thebrowser.Browser")
            ],
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

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .trash,
            domain: .trash,
            paths: [paths.home(".Trash")],
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
