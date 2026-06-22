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
    case failed(String)
    case stillPresent(URL)

    var errorDescription: String? {
        switch self {
        case let .systemApp(name):
            "\(name) is protected by macOS and can't be moved to Trash from here."
        case let .missing(url):
            "The app was not found at \(url.path). Rescan Applications and try again."
        case let .failed(message):
            message
        case let .stillPresent(url):
            "The app is still present at \(url.path). macOS did not complete the move to Trash."
        }
    }
}

actor AppInventoryService {
    private let recycleItems: @Sendable ([URL]) async throws -> Void
    private let trashItem: @Sendable (URL) throws -> Void
    private let fileExists: @Sendable (String) -> Bool
    private let verificationAttempts: Int
    private let verificationDelay: Duration

    init(
        recycleItems: @escaping @Sendable ([URL]) async throws -> Void = { urls in
            _ = try await NSWorkspace.shared.recycle(urls)
        },
        trashItem: @escaping @Sendable (URL) throws -> Void = { url in
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        },
        fileExists: @escaping @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        },
        verificationAttempts: Int = 8,
        verificationDelay: Duration = .milliseconds(150)
    ) {
        self.recycleItems = recycleItems
        self.trashItem = trashItem
        self.fileExists = fileExists
        self.verificationAttempts = verificationAttempts
        self.verificationDelay = verificationDelay
    }

    func scanInstalledApps() -> [AppItem] {
        let fileManager = FileManager.default
        var items: [AppItem] = []

        let searchPaths = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
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

                let size = directorySize(at: URL(fileURLWithPath: appPath), fileManager: fileManager)
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
            try await recycleItems([appURL])
        } catch {
            do {
                try trashItem(appURL)
            } catch {
                throw AppUninstallError.failed((error as NSError).localizedDescription)
            }
        }

        guard await waitUntilMissing(appURL.path) else {
            throw AppUninstallError.stillPresent(appURL)
        }
    }

    func revealInFinder(_ item: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func directorySize(at url: URL, fileManager: FileManager) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
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
}
