import Foundation

/// Shared pruning rules for project and nested-component discovery.
/// These directories contain VCS metadata, generated output, or installed
/// dependencies rather than independently maintained project source.
enum ProjectDiscoveryTraversalPolicy {
    private static let generatedDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".idea", ".vscode", ".firebase",
        "node_modules", "Pods", "DerivedData", ".dart_tool", ".pub-cache",
        ".gradle", ".cxx", ".build", ".swiftpm", ".nuxt", ".next",
        ".output", ".turbo", ".quasar", ".cache", ".expo", ".metro-cache",
        "vendor", ".npm", ".yarn", ".pnpm-store", ".bun", ".cargo",
        ".rustup", ".pyenv", ".nvm", ".volta", ".fnm", ".sdkman",
        ".rbenv", ".rvm", ".composer", ".gem", ".bundle", ".m2",
        ".nuget", ".dotnet", ".tox", ".venv", "venv"
    ]

    private static let componentOnlyDirectoryNames: Set<String> = [
        "target", "dist", "build", "bin", "obj"
    ]

    static func shouldSkipHomeSearch(at directory: URL, fileManager: FileManager) -> Bool {
        generatedDirectoryNames.contains(directory.lastPathComponent)
            || isFlutterSDKCheckout(directory, fileManager: fileManager)
            || isLibraryCacheDirectory(directory)
            || isToolchainCacheDirectory(directory)
    }

    static func shouldSkipComponent(
        at directory: URL,
        rootTechnology: ProjectTechnology,
        fileManager: FileManager
    ) -> Bool {
        let name = directory.lastPathComponent
        guard !generatedDirectoryNames.contains(name),
              !componentOnlyDirectoryNames.contains(name),
              !isFlutterSDKCheckout(directory, fileManager: fileManager),
              !isToolchainCacheDirectory(directory) else {
            return true
        }

        switch rootTechnology {
        case .flutter:
            return ["android", "ios", "linux", "macos", "web", "windows"].contains(name)
        case .reactNative:
            return ["android", "ios"].contains(name)
        case .dotNet:
            return name == "packages"
        default:
            return false
        }
    }

    private static func isLibraryCacheDirectory(_ directory: URL) -> Bool {
        directory.lastPathComponent == "Caches"
            && directory.deletingLastPathComponent().lastPathComponent == "Library"
    }

    private static func isToolchainCacheDirectory(_ directory: URL) -> Bool {
        let components = directory.pathComponents
        guard components.count >= 3 else { return false }
        let suffix = Array(components.suffix(3))
        if suffix == ["go", "pkg", "mod"] { return true }
        if suffix == ["Library", "pnpm", "store"] { return true }
        if suffix == ["Library", "Android", "sdk"] { return true }
        if Array(components.suffix(2)) == ["Android", "Sdk"] { return true }
        return false
    }

    private static func isFlutterSDKCheckout(_ directory: URL, fileManager: FileManager) -> Bool {
        let binFlutter = directory.appending(path: "bin/flutter")
        let frameworkLibrary = directory.appending(path: "packages/flutter/lib", directoryHint: .isDirectory)
        let engine = directory.appending(path: "engine", directoryHint: .isDirectory)
        let dev = directory.appending(path: "dev", directoryHint: .isDirectory)

        return fileManager.fileExists(atPath: binFlutter.path)
            && fileManager.fileExists(atPath: frameworkLibrary.path)
            && (fileManager.fileExists(atPath: engine.path) || fileManager.fileExists(atPath: dev.path))
    }
}
