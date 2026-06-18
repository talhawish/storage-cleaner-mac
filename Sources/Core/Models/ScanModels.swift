import Foundation

struct StorageFinding: Identifiable, Equatable, Sendable {
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64
    let itemCount: Int
    let safety: CleanupSafety
    let examples: [String]

    var id: StorageFindingKind { kind }
}

struct ScannerProgress: Identifiable, Equatable, Sendable {
    let kind: StorageFindingKind
    let title: String
    let state: ScannerProgressState
    let inspectedItemCount: Int
    let message: String

    var id: StorageFindingKind { kind }
}

enum ScannerProgressState: Equatable, Sendable {
    case pending
    case scanning
    case completed
    case skipped
}

enum StorageFindingKind: String, CaseIterable, Equatable, Sendable {
    case xcodeArtifacts
    case nodeDependencies
    case dockerArtifacts
    case flutterArtifacts
    case androidStudioArtifacts
    case androidPackages
    case aiModelCaches
    case largeVideos
    case screenRecordings
    case largePhotos
    case duplicatePhotos
    case duplicateVideos
    case screenshots
    case browserCaches
    case packageArtifacts
    case junkFiles
    case cliApps
    case trash

    var title: String {
        switch self {
        case .xcodeArtifacts: "Xcode artifacts"
        case .nodeDependencies: "Node dependencies"
        case .dockerArtifacts: "Docker artifacts"
        case .flutterArtifacts: "Flutter artifacts"
        case .androidStudioArtifacts: "Android Studio artifacts"
        case .androidPackages: "Leftover APKs"
        case .aiModelCaches: "AI model caches"
        case .largeVideos: "Large videos"
        case .screenRecordings: "Screen recordings"
        case .largePhotos: "Large photos"
        case .duplicatePhotos: "Duplicate photos"
        case .duplicateVideos: "Duplicate videos"
        case .screenshots: "Screenshots"
        case .browserCaches: "Browser caches"
        case .packageArtifacts: "Package artifacts"
        case .junkFiles: "Junk files"
        case .cliApps: "CLI apps & toolchains"
        case .trash: "Trash"
        }
    }

    var summary: String {
        switch self {
        case .xcodeArtifacts: "DerivedData, archives, simulators, and SwiftPM checkouts"
        case .nodeDependencies: "node_modules folders and npm, pnpm, or yarn cache data"
        case .dockerArtifacts: "Images, volumes, builder layers, and local container runtimes"
        case .flutterArtifacts: "Flutter build folders, pub cache files, and generated app bundles"
        case .androidStudioArtifacts: "Android Studio system data, emulator files, SDK caches, and Gradle outputs"
        case .androidPackages: "Loose APK, AAB, and emulator package outputs"
        case .aiModelCaches: "Local model downloads, embeddings, and generated cache files"
        case .largeVideos: "Large movie files, exports, captures, and old demos"
        case .screenRecordings: "macOS recordings, meeting captures, simulator demos, and tutorials"
        case .largePhotos: "RAW photos, large edited exports, and oversized image assets"
        case .duplicatePhotos: "Likely duplicate photos and repeated edited exports"
        case .duplicateVideos: "Likely duplicate video exports, recordings, and repeated captures"
        case .screenshots: "Desktop screenshots, simulator screenshots, and old review captures"
        case .browserCaches: "Safari, Chrome, Edge, Firefox, and Arc cache folders"
        case .packageArtifacts: "Gradle, Maven, Composer, pip, Poetry, Cargo, Go, and NuGet caches"
        case .junkFiles: "Temporary files, logs, stale downloads, and disposable archives"
        case .cliApps: "Homebrew formulae, Rust toolchains, Node version managers, and installed CLI tools"
        case .trash: "Files already moved to Trash but still occupying disk space"
        }
    }
}

enum CleanupSafety: String, Equatable, Sendable {
    case safe
    case review

    var title: String {
        switch self {
        case .safe: "Safe to clean"
        case .review: "Review first"
        }
    }
}

struct ScanSnapshot: Equatable, Sendable {
    let findings: [StorageFinding]
    let scannedItemCount: Int
    let duration: Duration

    var reclaimableBytes: Int64 {
        findings.reduce(0) { $0 + $1.bytes }
    }
}

enum ScanEvent: Equatable, Sendable {
    case progress(
        fraction: Double,
        currentLocation: String,
        scannedItemCount: Int,
        scannerProgress: [ScannerProgress]
    )
    case completed(ScanSnapshot)
}

enum ScanPhase: Equatable, Sendable {
    case idle
    case scanning
    case results
    case empty
    case permissionRequired
    case failed(message: String)
}
