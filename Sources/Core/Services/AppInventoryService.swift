import AppKit
import Foundation

struct AppItem: Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String
    let url: URL
    let sizeBytes: Int64
    let isSystemApp: Bool

    var id: String { bundleIdentifier }

    var displayName: String {
        name.replacingOccurrences(of: ".app", with: "")
    }
}

actor AppInventoryService {
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
        let workspace = NSWorkspace.shared
        _ = try await workspace.recycle([item.url])
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
}
