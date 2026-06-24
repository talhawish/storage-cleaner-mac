import Foundation

struct StorageFinding: Identifiable, Equatable, Hashable, Sendable {
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64
    let itemCount: Int
    let safety: CleanupSafety
    let examples: [String]
    let filePaths: [URL]
    /// Precomputed per-path byte counts captured during the scan so the detail view can show
    /// individual sizes without re-enumerating every directory on each navigation.
    var pathBytes: [URL: Int64] = [:]
    /// Populated only for duplicate findings: the byte-identical groups behind `filePaths`,
    /// including each group's recommended copy to keep. Empty for every other finding kind.
    var duplicateGroups: [DuplicateGroup] = []

    var id: StorageFindingKind { kind }

    /// Every URL this finding accounts for. For duplicate findings this also includes the kept
    /// copies (which live in `duplicateGroups` but not in `filePaths`), so deleting any copy —
    /// including one the user re-elected to keep — is correctly tracked for pruning and audits.
    var trackedURLs: [URL] {
        guard !duplicateGroups.isEmpty else { return filePaths }

        var seen = Set(filePaths)
        var urls = filePaths
        for group in duplicateGroups {
            for url in group.files.map(\.url) where seen.insert(url).inserted {
                urls.append(url)
            }
        }
        return urls
    }

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
    case reactNativeArtifacts
    case androidStudioArtifacts
    case androidPackages
    case aiModelCaches
    case largeFiles
    case largeVideos
    case screenRecordings
    case largePhotos
    case duplicatePhotos
    case duplicateVideos
    case duplicateDocuments
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
    case runtimeVersions
    case installerLeftovers
    case orphanedAppSupport
    case orphanedAppCaches
    case orphanedAppContainers
    case orphanedAppPreferences
    case oldCrashReports
    case trash

    var title: String {
        switch self {
        case .xcodeArtifacts: "Xcode artifacts"
        case .nodeDependencies: "Node.js dependencies"
        case .dockerArtifacts: "Docker artifacts"
        case .flutterArtifacts: "Flutter artifacts"
        case .reactNativeArtifacts: "React Native artifacts"
        case .androidStudioArtifacts: "Android Studio artifacts"
        case .androidPackages: "Leftover APKs"
        case .aiModelCaches: "AI model caches"
        case .largeFiles: "Large files"
        case .largeVideos: "Large videos"
        case .screenRecordings: "Screen recordings"
        case .largePhotos: "Large photos"
        case .duplicatePhotos: "Duplicate photos"
        case .duplicateVideos: "Duplicate videos"
        case .duplicateDocuments: "Duplicate documents"
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
        case .runtimeVersions: "Duplicate runtime versions"
        case .installerLeftovers: "Leftover installers"
        case .orphanedAppSupport: "Orphaned app data"
        case .orphanedAppCaches: "Orphaned app caches"
        case .orphanedAppContainers: "Orphaned app containers"
        case .orphanedAppPreferences: "Orphaned app preferences"
        case .oldCrashReports: "Old crash reports"
        case .trash: "Trash"
        }
    }

    var summary: String {
        switch self {
        case .xcodeArtifacts: "DerivedData, archives, simulators, and SwiftPM checkouts"
        case .nodeDependencies: "npm, pnpm, yarn, and Bun caches and installed packages"
        case .dockerArtifacts: "Images, volumes, builder layers, and local container runtimes"
        case .flutterArtifacts: "Flutter build folders, pub cache files, and generated app bundles"
        case .reactNativeArtifacts: "Per-project iOS Pods, iOS/Android build, and Gradle outputs from React Native"
        case .androidStudioArtifacts: "Android Studio system data, emulator files, SDK caches, and Gradle outputs"
        case .androidPackages: "Loose APK and AAB build outputs"
        case .aiModelCaches: "Local model downloads, embeddings, and generated cache files"
        case .largeFiles: "Large documents, archives, installers, datasets, disk images, exports, and other files"
        case .largeVideos: "Large movie files, exports, captures, and old demos"
        case .screenRecordings: "macOS recordings, meeting captures, simulator demos, and tutorials"
        case .largePhotos: "RAW photos, large edited exports, and oversized image assets"
        case .duplicatePhotos: "Likely duplicate photos and repeated edited exports"
        case .duplicateVideos: "Likely duplicate video exports, recordings, and repeated captures"
        case .duplicateDocuments: "Likely duplicate PDFs, spreadsheets, archives, and repeated downloads"
        case .screenshots: "Desktop screenshots, simulator screenshots, and old review captures"
        case .browserCaches: "Safari, Chrome, Edge, Firefox, Arc, Brave, and Chromium cache folders"
        case .pythonDependencies: "pip, Poetry, conda, pyenv, and virtual environment caches"
        case .rustDependencies: "Cargo registry, build artifacts, and installed toolchains"
        case .goDependencies: "Go module cache and downloaded packages"
        case .phpDependencies: "Composer project vendor folders and downloaded cache"
        case .rubyDependencies: "RubyGems cache, Bundler packages, rbenv and RVM versions"
        case .dotnetDependencies: "NuGet packages and .NET build caches"
        case .gradleDependencies: "Gradle build cache, Maven repository, and downloaded dependencies"
        case .junkFiles: "Temporary files, logs, and stale downloads"
        case .cliApps: "Homebrew formulae, Rust toolchains, Node version managers, and installed CLI tools"
        case .runtimeVersions: "Older language runtime and SDK versions kept by version managers"
        case .installerLeftovers: "Loose DMG, PKG, IPA, ISO, and other installer files in Downloads and Desktop"
        case .orphanedAppSupport: "Application Support folders left behind by uninstalled apps"
        case .orphanedAppCaches: "Cache folders left behind by uninstalled apps"
        case .orphanedAppContainers: "Sandbox containers left behind by uninstalled apps"
        case .orphanedAppPreferences: "Preference files left behind by uninstalled apps"
        case .oldCrashReports: "Stale crash reports and diagnostic logs in your user Library"
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
    case failed(message: String)
}

enum ScanPhase: Equatable, Sendable {
    case idle
    case scanning
    case results
    case empty
    case permissionRequired
    case failed(message: String)
}
