import Foundation

struct StorageFinding: Identifiable, Equatable, Hashable, Sendable {
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64
    let itemCount: Int
    let safety: CleanupSafety
    let examples: [String]
    let filePaths: [URL]

    var id: StorageFindingKind { kind }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
    }
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
    case largeFiles
    case largeVideos
    case screenRecordings
    case largePhotos
    case duplicatePhotos
    case duplicateVideos
    case screenshots
    case browserCaches
    case pythonDependencies
    case rustDependencies
    case goDependencies
    case phpDependencies
    case rubyDependencies
    case dotnetDependencies
    case gradleDependencies
    case junkFiles
    case cliApps
    case trash

    var title: String {
        switch self {
        case .xcodeArtifacts: "Xcode artifacts"
        case .nodeDependencies: "Node.js dependencies"
        case .dockerArtifacts: "Docker artifacts"
        case .flutterArtifacts: "Flutter artifacts"
        case .androidStudioArtifacts: "Android Studio artifacts"
        case .androidPackages: "Leftover APKs"
        case .aiModelCaches: "AI model caches"
        case .largeFiles: "Large files"
        case .largeVideos: "Large videos"
        case .screenRecordings: "Screen recordings"
        case .largePhotos: "Large photos"
        case .duplicatePhotos: "Duplicate photos"
        case .duplicateVideos: "Duplicate videos"
        case .screenshots: "Screenshots"
        case .browserCaches: "Browser caches"
        case .pythonDependencies: "Python dependencies"
        case .rustDependencies: "Rust dependencies"
        case .goDependencies: "Go dependencies"
        case .phpDependencies: "PHP dependencies"
        case .rubyDependencies: "Ruby dependencies"
        case .dotnetDependencies: ".NET dependencies"
        case .gradleDependencies: "Gradle & Maven dependencies"
        case .junkFiles: "Junk files"
        case .cliApps: "CLI apps & toolchains"
        case .trash: "Trash"
        }
    }

    var summary: String {
        switch self {
        case .xcodeArtifacts: "DerivedData, archives, simulators, and SwiftPM checkouts"
        case .nodeDependencies: "npm, pnpm, yarn, and Bun caches and installed packages"
        case .dockerArtifacts: "Images, volumes, builder layers, and local container runtimes"
        case .flutterArtifacts: "Flutter build folders, pub cache files, and generated app bundles"
        case .androidStudioArtifacts: "Android Studio system data, emulator files, SDK caches, and Gradle outputs"
        case .androidPackages: "Loose APK and AAB build outputs"
        case .aiModelCaches: "Local model downloads, embeddings, and generated cache files"
        case .largeFiles: "Large archives, installers, datasets, disk images, and exports"
        case .largeVideos: "Large movie files, exports, captures, and old demos"
        case .screenRecordings: "macOS recordings, meeting captures, simulator demos, and tutorials"
        case .largePhotos: "RAW photos, large edited exports, and oversized image assets"
        case .duplicatePhotos: "Likely duplicate photos and repeated edited exports"
        case .duplicateVideos: "Likely duplicate video exports, recordings, and repeated captures"
        case .screenshots: "Desktop screenshots, simulator screenshots, and old review captures"
        case .browserCaches: "Safari, Chrome, Edge, Firefox, and Arc cache folders"
        case .pythonDependencies: "pip, Poetry, conda, pyenv, and virtual environment caches"
        case .rustDependencies: "Cargo registry, build artifacts, and installed toolchains"
        case .goDependencies: "Go module cache and downloaded packages"
        case .phpDependencies: "Composer downloaded packages and cache"
        case .rubyDependencies: "RubyGems cache, Bundler packages, rbenv and RVM versions"
        case .dotnetDependencies: "NuGet packages and .NET build caches"
        case .gradleDependencies: "Gradle build cache, Maven repository, and downloaded dependencies"
        case .junkFiles: "Temporary files, logs, and stale downloads"
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
