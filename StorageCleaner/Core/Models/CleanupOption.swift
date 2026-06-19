import Foundation

struct CleanupOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let iconColor: String
    let domain: StorageDomain
    let safety: CleanupSafety
    let paths: [String]
    let isSafeByDefault: Bool
    let category: Category

    enum Category: String, CaseIterable, Sendable {
        case developerTools = "Developer Tools"
        case caches = "Caches"
        case media = "Media"
        case system = "System"
        case emulators = "Emulators"
    }
}

enum CleanupOptionsRegistry {
    static let allOptions: [CleanupOption] = [
        // Developer Tools
        CleanupOption(
            id: "xcode-derived",
            name: "Xcode DerivedData",
            description: "Build intermediates and index data for Xcode projects",
            icon: "hammer.fill",
            iconColor: "blue",
            domain: .appleDevelopment,
            safety: .safe,
            paths: ["~/Library/Developer/Xcode/DerivedData"],
            isSafeByDefault: true,
            category: .developerTools
        ),
        CleanupOption(
            id: "xcode-archives",
            name: "Xcode Archives",
            description: "Older Xcode archive files (.xcarchive)",
            icon: "archivebox.fill",
            iconColor: "blue",
            domain: .appleDevelopment,
            safety: .safe,
            paths: ["~/Library/Developer/Xcode/Archives"],
            isSafeByDefault: true,
            category: .developerTools
        ),
        CleanupOption(
            id: "swiftpm-checkouts",
            name: "SwiftPM Checkouts",
            description: "Swift Package Manager downloaded source checkouts",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "orange",
            domain: .appleDevelopment,
            safety: .safe,
            paths: ["~/Library/Caches/org.swift.swiftpm"],
            isSafeByDefault: true,
            category: .developerTools
        ),
        CleanupOption(
            id: "node-modules",
            name: "Node.js / Bun Cache",
            description: "npm, pnpm, yarn, and Bun caches and installed packages",
            icon: "globe",
            iconColor: "green",
            domain: .webDevelopment,
            safety: .review,
            paths: [
                "~/.npm",
                "~/.cache/yarn",
                "~/.bun/install/cache",
                "~/.bun/install/global"
            ],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "gradle-cache",
            name: "Gradle & Maven Cache",
            description: "Gradle build cache, Maven repository, and downloaded dependencies",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "indigo",
            domain: .mobileDevelopment,
            safety: .review,
            paths: ["~/.gradle/caches", "~/.m2/repository"],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "flutter-cache",
            name: "Flutter Cache",
            description: "Flutter SDK cache and pub packages",
            icon: "wind",
            iconColor: "cyan",
            domain: .mobileDevelopment,
            safety: .review,
            paths: ["~/.pub-cache", "~/Library/Caches/flutter"],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "docker-cache",
            name: "Docker Cache",
            description: "Docker images, layers, and builder cache",
            icon: "shippingbox.fill",
            iconColor: "teal",
            domain: .containers,
            safety: .review,
            paths: [
                "~/.docker",
                "~/Library/Containers/com.docker.docker",
                "~/Library/Application Support/OrbStack"
            ],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "cargo-cache",
            name: "Cargo Cache",
            description: "Rust package registry and build artifacts",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "orange",
            domain: .otherCaches,
            safety: .review,
            paths: ["~/.cargo/registry", "~/.cargo/git/db"],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "pip-cache",
            name: "Python Cache",
            description: "pip, Poetry, conda, uv, and virtual environment caches",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "yellow",
            domain: .otherCaches,
            safety: .safe,
            paths: [
                "~/Library/Caches/pip",
                "~/Library/Caches/pypoetry",
                "~/Library/Caches/uv",
                "~/.cache/pip",
                "~/.cache/uv"
            ],
            isSafeByDefault: true,
            category: .developerTools
        ),
        CleanupOption(
            id: "composer-cache",
            name: "Composer Cache",
            description: "PHP Composer downloaded packages and cache",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "purple",
            domain: .otherCaches,
            safety: .review,
            paths: [
                "~/Library/Caches/composer",
                "~/.composer/cache"
            ],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "ruby-cache",
            name: "Ruby Cache",
            description: "RubyGems cache, Bundler packages, and version manager data",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "red",
            domain: .otherCaches,
            safety: .review,
            paths: [
                "~/Library/Caches/gems",
                "~/.gem/cache"
            ],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "nuget-cache",
            name: ".NET NuGet Cache",
            description: "NuGet downloaded packages and .NET tool cache",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "purple",
            domain: .otherCaches,
            safety: .review,
            paths: [
                "~/.nuget/packages",
                "~/.dotnet/tools",
                "~/Library/Caches/NuGet"
            ],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "go-cache",
            name: "Go Module Cache",
            description: "Go downloaded modules and packages",
            icon: "chevron.left.forwardslash.chevron.right",
            iconColor: "cyan",
            domain: .otherCaches,
            safety: .review,
            paths: ["~/go/pkg/mod"],
            isSafeByDefault: false,
            category: .developerTools
        ),
        CleanupOption(
            id: "homebrew-cache",
            name: "Homebrew Cache",
            description: "Homebrew downloaded formulae and cask packages",
            icon: "wineglass.fill",
            iconColor: "yellow",
            domain: .cliTooling,
            safety: .safe,
            paths: ["~/Library/Caches/Homebrew"],
            isSafeByDefault: true,
            category: .developerTools
        ),

        // Caches
        CleanupOption(
            id: "browser-cache",
            name: "Browser Caches",
            description: "Safari, Chrome, Edge, Firefox, Arc, and Brave caches",
            icon: "safari.fill",
            iconColor: "teal",
            domain: .browserData,
            safety: .safe,
            paths: [
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Caches/Google/Chrome",
                "~/Library/Caches/Microsoft Edge",
                "~/Library/Caches/Firefox",
                "~/Library/Caches/company.thebrowser.Browser",
                "~/Library/Caches/BraveSoftware",
                "~/Library/Caches/Chromium"
            ],
            isSafeByDefault: true,
            category: .caches
        ),
        CleanupOption(
            id: "system-logs",
            name: "System Logs",
            description: "Older system and application log files",
            icon: "doc.text.fill",
            iconColor: "orange",
            domain: .otherCaches,
            safety: .safe,
            paths: ["~/Library/Logs"],
            isSafeByDefault: true,
            category: .caches
        ),
        CleanupOption(
            id: "ai-model-cache",
            name: "AI Model Cache",
            description: "Ollama, HuggingFace, LM Studio downloaded models",
            icon: "sparkles",
            iconColor: "violet",
            domain: .artificialIntelligence,
            safety: .review,
            paths: [
                "~/.ollama/models",
                "~/.cache/huggingface",
                "~/Library/Application Support/LM Studio"
            ],
            isSafeByDefault: false,
            category: .caches
        ),

        // System
        CleanupOption(
            id: "trash",
            name: "Trash",
            description: "Files already in Trash still occupying disk space",
            icon: "trash.fill",
            iconColor: "gray",
            domain: .trash,
            safety: .review,
            paths: ["~/.Trash"],
            isSafeByDefault: false,
            category: .system
        ),
        CleanupOption(
            id: "tmp-files",
            name: "Temporary Files",
            description: "Stale temporary files and crash logs",
            icon: "doc.badge.clock.fill",
            iconColor: "orange",
            domain: .otherCaches,
            safety: .safe,
            paths: ["/tmp", "~/Library/Caches/com.apple-crashreporter"],
            isSafeByDefault: true,
            category: .system
        ),

        // Emulators
        CleanupOption(
            id: "android-emulators",
            name: "Android Emulator Data",
            description: "Android Virtual Device images, snapshots, and SD card data",
            icon: "apps.iphone",
            iconColor: "green",
            domain: .mobileDevelopment,
            safety: .review,
            paths: ["~/.android/avd", "~/Library/Android/sdk/system-images"],
            isSafeByDefault: false,
            category: .emulators
        ),
        CleanupOption(
            id: "ios-simulators",
            name: "iOS Simulator Data",
            description: "Xcode simulator devices, runtimes, and cached data",
            icon: "iphone.radiowaves.left.and.right",
            iconColor: "blue",
            domain: .appleDevelopment,
            safety: .review,
            paths: ["~/Library/Developer/CoreSimulator"],
            isSafeByDefault: false,
            category: .emulators
        ),

        // Media
        CleanupOption(
            id: "large-videos",
            name: "Large Video Files",
            description: "Movies, exports, and recordings over 100MB",
            icon: "film.fill",
            iconColor: "pink",
            domain: .media,
            safety: .review,
            paths: ["~/Movies", "~/Downloads", "~/Desktop"],
            isSafeByDefault: false,
            category: .media
        ),
        CleanupOption(
            id: "screenshots",
            name: "Screenshots",
            description: "Desktop screenshots and simulator captures",
            icon: "camera.viewfinder",
            iconColor: "indigo",
            domain: .screenshots,
            safety: .review,
            paths: ["~/Desktop", "~/Pictures", "~/Downloads"],
            isSafeByDefault: false,
            category: .media
        ),
        CleanupOption(
            id: "screen-recordings",
            name: "Screen Recordings",
            description: "macOS screen recordings and meeting captures",
            icon: "record.circle.fill",
            iconColor: "red",
            domain: .media,
            safety: .review,
            paths: ["~/Movies", "~/Desktop", "~/Downloads"],
            isSafeByDefault: false,
            category: .media
        )
    ]

    static var safeByDefaultIDs: Set<String> {
        Set(allOptions.filter(\.isSafeByDefault).map(\.id))
    }

    static func options(for category: CleanupOption.Category) -> [CleanupOption] {
        allOptions.filter { $0.category == category }
    }

    static func option(byID id: String) -> CleanupOption? {
        allOptions.first { $0.id == id }
    }

    static var categories: [CleanupOption.Category] {
        CleanupOption.Category.allCases
    }
}
