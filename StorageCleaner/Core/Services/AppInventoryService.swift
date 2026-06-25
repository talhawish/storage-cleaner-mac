import AppKit
import Foundation

struct AppItem: Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String
    let url: URL
    let sizeBytes: Int64
    let isSystemApp: Bool

    var id: String { url.standardizedFileURL.path }

    var displayName: String {
        name.replacingOccurrences(of: ".app", with: "")
    }
}

enum AppUninstallError: LocalizedError, Sendable {
    case systemApp(String)
    case missing(URL)
    case permissionDenied(URL)
    case failed(URL, String)
    case stillPresent(URL)

    var errorDescription: String? {
        switch self {
        case let .systemApp(name):
            "\(name) is protected by macOS and can't be uninstalled from here."
        case let .missing(url):
            "The app was not found at \(url.path). Rescan Applications and try again."
        case let .permissionDenied(url):
            "macOS denied permission to uninstall \(url.lastPathComponent). "
                + "Apps installed for all users may require administrator approval."
        case let .failed(url, message):
            "Couldn't uninstall \(url.lastPathComponent): \(message)"
        case let .stillPresent(url):
            "The app is still present at \(url.path). macOS did not complete the uninstall."
        }
    }
}

actor AppInventoryService {
    private let uninstallAppBundle: @Sendable (URL) async throws -> Void
    private let fileExists: @Sendable (String) -> Bool
    private let directorySizer: @Sendable (URL) async -> Int64
    private let verificationAttempts: Int
    private let verificationDelay: Duration

    init(
        uninstallAppBundle: @escaping @Sendable (URL) async throws -> Void = AppBundleUninstaller.live.uninstall,
        fileExists: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        },
        directorySizer: @escaping @Sendable (URL) async -> Int64 = AppInventoryService.liveSize,
        verificationAttempts: Int = 8,
        verificationDelay: Duration = .milliseconds(150)
    ) {
        self.uninstallAppBundle = uninstallAppBundle
        self.fileExists = fileExists
        self.directorySizer = directorySizer
        self.verificationAttempts = verificationAttempts
        self.verificationDelay = verificationDelay
    }

    func scanInstalledApps() async -> [AppItem] {
        let fileManager = FileManager.default
        var items: [AppItem] = []

        let searchPaths = [
            "/Applications",
            UserHomeDirectory.url.appendingPathComponent("Applications").path
        ]

        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents where item.pathExtension == "app" {
                guard !Task.isCancelled else { return items }

                let appPath = item.path
                let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
                let name = (appPath as NSString).lastPathComponent
                    .replacingOccurrences(of: ".app", with: "")

                var bundleID = name
                if let plist = NSDictionary(contentsOfFile: plistPath),
                   let bid = plist["CFBundleIdentifier"] as? String {
                    bundleID = bid
                }

                let size = await directorySizer(URL(fileURLWithPath: appPath))
                let isSystem = appPath.hasPrefix("/System")

                items.append(AppItem(
                    name: name,
                    bundleIdentifier: bundleID,
                    url: URL(fileURLWithPath: appPath),
                    sizeBytes: size,
                    isSystemApp: isSystem
                ))
            }
        }

        return items
    }

    func uninstallApp(_ item: AppItem) async throws {
        let appURL = item.url.standardizedFileURL
        guard !item.isSystemApp else { throw AppUninstallError.systemApp(item.displayName) }
        guard fileExists(appURL.path) else { throw AppUninstallError.missing(appURL) }

        do {
            try await uninstallAppBundle(appURL)
        } catch {
            throw Self.uninstallError(for: error, appURL: appURL)
        }

        guard await waitUntilMissing(appURL.path) else {
            throw AppUninstallError.stillPresent(appURL)
        }
    }

    func revealInFinder(_ item: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Production sizer wired in by default. Tries `du -sk` first (which matches what
    /// Finder, System Settings → Storage → Applications, and `du` itself report) and
    /// falls back to the FileManager walker when `du` is unavailable or fails.
    static let liveSize: @Sendable (URL) async -> Int64 = { url in
        if let duBytes = await duBasedSize(at: url) {
            return duBytes
        }
        return directorySize(at: url, fileManager: .default)
    }

    /// Returns the on-disk size of `url` in bytes using `/usr/bin/du -sk`, which
    /// reports the same number Finder, System Settings, and `du` show. Unlike
    /// `directorySize(at:fileManager:)`, this includes AppleDouble `._*` sidecars
    /// and extended-attribute overflow blocks — both of which APFS hides from
    /// `FileManager.enumerator`. Returns `nil` if `du` cannot be launched or its
    /// output cannot be parsed, so the caller can fall back to the walker.
    static func duBasedSize(
        at url: URL,
        executor: any ProcessExecuting = SystemProcessExecutor()
    ) async -> Int64? {
        let duURL = URL(fileURLWithPath: "/usr/bin/du")
        let result: ProcessRunResult
        do {
            result = try await executor.run(executable: duURL, arguments: ["-sk", url.path])
        } catch {
            return nil
        }
        guard result.exitCode == 0,
              let output = String(data: result.standardOutput, encoding: .utf8) else {
            return nil
        }
        let token = output.split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "\n" }).first
        guard let token, let kilobytes = Int64(token) else { return nil }
        return kilobytes * 1024
    }

    /// Walks an `.app` bundle with `FileManager.enumerator` and sums the
    /// `fileAllocatedSize` of every regular file inside it.
    ///
    /// Hidden files are walked (the enumerator runs with no options), so
    /// `Contents/.DS_Store`, `.localized` markers, and similar `.`-prefixed
    /// files contribute to the total — they consume real blocks on disk and
    /// are reclaimed when the user uninstalls the app. This walker does NOT
    /// see AppleDouble `._*` files (APFS hides them from `FileManager`),
    /// nor xattr overflow blocks; for that coverage use `duBasedSize(at:)`.
    /// Used as a fallback when `du` is unavailable and as the deterministic
    /// testable backend for unit tests.
    static func directorySize(at url: URL, fileManager: FileManager) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: []
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let childURL as URL in enumerator {
            let values = try? childURL.resourceValues(forKeys: Set(resourceKeys))
            guard values?.isRegularFile == true else { continue }
            total += Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }
        return total
    }

    private func waitUntilMissing(_ path: String) async -> Bool {
        for _ in 0..<verificationAttempts {
            guard fileExists(path) else { return true }
            try? await Task.sleep(for: verificationDelay)
        }
        return !fileExists(path)
    }

    private static func uninstallError(for error: Error, appURL: URL) -> AppUninstallError {
        if case let AppBundleUninstallerError.administratorApprovalFailed(_, message) = error {
            return .failed(appURL, message)
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let code = CocoaError.Code(rawValue: nsError.code)
            if code == .fileWriteNoPermission || code == .fileReadNoPermission {
                return .permissionDenied(appURL)
            }
        }

        let message = nsError.localizedDescription.isEmpty
            ? "The system did not provide an error message."
            : nsError.localizedDescription
        return .failed(appURL, message)
    }
}
