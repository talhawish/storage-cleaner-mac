import Foundation

enum DependencyPaths {
    private static let home = UserHomeDirectory.url

    static func home(_ path: String) -> URL {
        home.appendingPathComponent(path)
    }

    // MARK: - Node.js / Bun

    enum Node {
        static let cacheDirs: [URL] = [
            home(".npm"),
            home("Library/pnpm/store"),
            home(".yarn"),
            home(".cache/yarn"),
            home(".bun/install/cache"),
            home(".bun/install/global")
        ]
    }

    // MARK: - Python

    enum Python {
        static let cacheDirs: [URL] = [
            home("Library/Caches/pip"),
            home("Library/Caches/pypoetry"),
            home("Library/Caches/conda"),
            home("Library/Caches/pipenv"),
            home("Library/Caches/uv"),
            home(".cache/pip"),
            home(".cache/uv"),
            home(".pyenv/versions"),
            home(".local/share/virtualenvs")
        ]
    }

    // MARK: - Rust

    enum Rust {
        static let cacheDirs: [URL] = [
            home(".cargo/registry"),
            home(".cargo/git/db")
        ]
    }

    // MARK: - Go

    enum Golang {
        static let cacheDirs: [URL] = [
            home("go/pkg/mod")
        ]
    }

    // MARK: - PHP (Composer)

    enum PHP {
        static let cacheDirs: [URL] = [
            home("Library/Caches/composer"),
            home(".composer/cache")
        ]
        static let projectVendorMaxDepth = Projects.maxDepth + 1
    }

    // MARK: - Ruby

    enum Ruby {
        static let cacheDirs: [URL] = [
            home("Library/Caches/gems"),
            home(".gem/cache"),
            home(".rbenv/versions"),
            home(".rvm/gems"),
            home(".rvm/rubies")
        ]
    }

    // MARK: - .NET (NuGet)

    enum DotNet {
        static let cacheDirs: [URL] = [
            home(".nuget/packages"),
            home(".dotnet/tools"),
            home("Library/Caches/NuGet")
        ]
    }

    // MARK: - Gradle / Maven

    enum Gradle {
        static let cacheDirs: [URL] = [
            home(".gradle/caches"),
            home(".m2/repository")
        ]
    }

    // MARK: - CLI Tools

    enum CLI {
        static let homeDirs: [URL] = [
            home(".rustup"),
            home(".volta"),
            home(".nvm"),
            home(".fnm"),
            home("Library/Caches/Homebrew"),
            home(".cargo/bin"),
            home(".pyenv"),
            home(".rbenv"),
            home(".rvm"),
            home(".bun/bin")
        ]

        static let systemDirs: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/Caskroom", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/var", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Caskroom", isDirectory: true)
        ]
    }

    // MARK: - Apple Development

    enum Apple {
        static let derivedData = home("Library/Developer/Xcode/DerivedData")
        static let archives = home("Library/Developer/Xcode/Archives")
        static let coreSimulator = home("Library/Developer/CoreSimulator")
        static let swiftPM = home("Library/Caches/org.swift.swiftpm")
    }

    // MARK: - Docker / Containers

    enum Docker {
        static let cacheDirs: [URL] = [
            home("Library/Containers/com.docker.docker"),
            home(".docker"),
            home(".colima"),
            home("Library/Application Support/OrbStack")
        ]
    }

    // MARK: - Flutter

    enum Flutter {
        static let cacheDirs: [URL] = [
            home(".pub-cache"),
            home("Library/Caches/flutter"),
            home("Developer/flutter")
        ]
    }

    // MARK: - React Native

    /// Bare React Native only — Expo-specific paths (`.expo`, Expo Go caches) are
    /// intentionally omitted. Project-local build artifacts are discovered by
    /// walking `Projects.searchRoots` and are not listed here.
    enum ReactNative {
        static let projectDependencyMaxDepth = Projects.maxDepth + 1

        /// Subpaths of a React Native project root that hold per-project build artifacts.
        /// All are matched by name via `ProjectTechnology.reactNative.dependencyDirectoryNames`
        /// so `ProjectHibernationService` can remove them with the same machinery used for
        /// other technologies.
        static let buildSubpaths: [String] = [
            "ios/Pods",
            "ios/build",
            "android/app/build",
            "android/.gradle",
            "android/build"
        ]
    }

    // MARK: - Android

    enum Android {
        static let cacheDirs: [URL] = [
            home("Library/Android/sdk"),
            home("Library/Android/sdk/system-images"),
            home(".android/avd"),
            home("Library/Caches/Google/AndroidStudio"),
            home(".gradle/caches")
        ]
    }

    // MARK: - AI Models

    enum ArtificialIntelligence {
        static let cacheDirs: [URL] = [
            home(".ollama/models"),
            home(".cache/huggingface"),
            home("Library/Application Support/LM Studio"),
            home("stable-diffusion-webui/models")
        ]
    }

    // MARK: - Browser Caches

    enum Browser {
        static let cacheDirs: [URL] = [
            home("Library/Caches/com.apple.Safari"),
            home("Library/Caches/Google/Chrome"),
            home("Library/Caches/Microsoft Edge"),
            home("Library/Caches/Firefox"),
            home("Library/Caches/company.thebrowser.Browser"),
            home("Library/Caches/BraveSoftware"),
            home("Library/Caches/Chromium")
        ]
    }

    // MARK: - Media Roots

    enum Media {
        static let imageExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif",
            "webp", "heic", "heif", "raw", "dng"
        ]
        static let videoExtensions: Set<String> = [
            "mov", "mp4", "m4v", "avi", "mkv", "webm"
        ]
    }

    // MARK: - Document & Archive Roots

    /// File types surfaced by duplicate-document detection: office documents, spreadsheets,
    /// presentations, vector/markup files, e-books, and the common compressed-archive formats.
    /// `svg` lives here (not under `Media`) so vector exports are classified as documents.
    enum Documents {
        static let documentExtensions: Set<String> = [
            // Documents
            "pdf", "doc", "docx", "rtf", "rtfd", "pages", "odt", "epub", "txt", "md",
            // Spreadsheets
            "csv", "tsv", "xls", "xlsx", "numbers", "ods",
            // Presentations
            "ppt", "pptx", "key", "odp",
            // Vector & markup
            "svg",
            // Compressed archives
            "zip", "tar", "gz", "tgz", "bz2", "tbz", "xz", "txz", "zst", "7z", "rar"
        ]
    }

    // MARK: - Leftover Installers

    /// Loose installer and package files that linger after an app is installed. Scanned regardless of
    /// size, so even small leftover packages surface (unlike the 100 MB Large Files threshold).
    enum Leftovers {
        static var searchRoots: [URL] {
            ScanPreferences.includingExternalVolumes([
                home("Downloads"),
                home("Desktop"),
                home("Documents")
            ])
        }

        /// Installer and package extensions treated as leftovers. Android packages (`apk`/`aab`) are
        /// intentionally excluded — they have their own `androidPackages` scanner — so the Leftovers
        /// section surfaces both kinds without ever double-counting the same file.
        static let installerExtensions: Set<String> = [
            "dmg", "pkg", "mpkg", "iso", "xip", "msi", "exe",
            "ipa", "ipsw", "deb", "rpm"
        ]

        static let androidPackageExtensions: Set<String> = [
            "apk", "aab"
        ]

        /// Package-like file types that should still surface in Large Files if they cross the
        /// threshold, even when the executable bit is set by a build or download tool.
        static let largeFilePackageExtensions = installerExtensions.union(androidPackageExtensions)

        /// Path components that mark build outputs or dependency caches. Matches inside these are
        /// skipped so a project's own generated installers are never flagged as leftovers.
        static let blockedPathComponents: Set<String> = [
            ".build", ".git", ".gradle", ".swiftpm", "DerivedData",
            "Pods", "build", "node_modules", "vendor", "Library", "Applications"
        ]
    }

    // MARK: - Developer Project Roots

    /// Common locations where developers keep source-code projects. Used by
    /// `ProjectActivityScanner` to discover projects across the home directory.
    enum Projects {
        static var searchRoots: [URL] {
            ScanPreferences.includingExternalVolumes([
                home("Developer"),
                home("Documents"),
                home("Desktop"),
                home("Projects"),
                home("Code"),
                home("Work"),
                home("dev"),
                home("src"),
                home("repos"),
                home("git"),
                home("workspace"),
                home("Sites"),
                home("development"),
                home("IdeaProjects"),
                home("AndroidStudioProjects"),
                home("StudioProjects"),
                home("Documents/GitHub")
            ])
        }

        /// How deep to descend into each search root before giving up on finding
        /// a project marker. Descent stops as soon as a project is detected.
        static let maxDepth = 4
    }

    // MARK: - System Junk

    /// Re-export of `SystemJunkPaths` so callers that already use `DependencyPaths.SystemJunk.…`
    /// continue to compile without changes. The actual data lives in `SystemJunkPaths.swift` to
    /// keep this enum under the 350-line type-body cap.
    enum SystemJunk {
        static let applicationSupport = SystemJunkPaths.applicationSupport
        static let caches = SystemJunkPaths.caches
        static let containers = SystemJunkPaths.containers
        static let groupContainers = SystemJunkPaths.groupContainers
        static let preferences = SystemJunkPaths.preferences
        static let savedApplicationState = SystemJunkPaths.savedApplicationState
        static let diagnosticReports = SystemJunkPaths.diagnosticReports
        static let crashReporter = SystemJunkPaths.crashReporter
    }

    // MARK: - Cleanup Quick Clean Paths

    enum QuickClean {
        static let allPaths: [String] = [
            "~/Library/Developer/Xcode/DerivedData",
            "~/Library/Developer/Xcode/Archives",
            "~/Library/Caches/org.swift.swiftpm",
            "~/.npm",
            "~/.cache/yarn",
            "~/.bun/install/cache",
            "~/.docker",
            "~/Library/Containers/com.docker.docker",
            "~/.pub-cache",
            "~/Library/Caches/flutter",
            "~/.gradle/caches",
            "~/.m2/repository",
            "~/.cargo/registry",
            "~/go/pkg/mod",
            "~/.nuget/packages",
            "~/Library/Caches/pip",
            "~/Library/Caches/composer",
            "~/.ollama/models",
            "~/.cache/huggingface",
            "~/Library/Application Support/LM Studio",
            "~/Library/Caches/com.apple.Safari",
            "~/Library/Caches/Google/Chrome",
            "~/Library/Caches/Microsoft Edge",
            "~/Library/Caches/Firefox",
            "~/Library/Caches/company.thebrowser.Browser",
            "~/.Trash"
        ]
    }
}
