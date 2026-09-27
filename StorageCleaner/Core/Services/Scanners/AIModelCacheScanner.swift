import Foundation

struct AIModelCacheScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .aiModelCaches
    let title = StorageFindingKind.aiModelCaches.title
    private let roots: [URL]
    private let repositoryRoots: [URL]
    private let collector: FileSystemCollector

    init(
        collector: FileSystemCollector,
        roots: [URL] = DependencyPaths.ArtificialIntelligence.cacheDirs,
        repositoryRoots: [URL] = [DependencyPaths.ArtificialIntelligence.huggingFaceHub]
    ) {
        self.collector = collector
        self.roots = roots
        self.repositoryRoots = repositoryRoots
    }

    func scan() async -> CategoryScanResult {
        let paths = AIModelStoreDiscovery.paths(in: roots, repositoryRoots: repositoryRoots)
        return await PathListScanner(
            kind: kind,
            domain: .artificialIntelligence,
            paths: paths,
            safety: .review,
            collector: collector
        ).scan()
    }
}

/// Shared by the inventory and Quick Clean so neither offers a whole app-data
/// folder or Hugging Face's datasets, credentials, and unrelated caches as models.
enum AIModelStoreDiscovery {
    static func paths(
        in roots: [URL],
        repositoryRoots: [URL] = [DependencyPaths.ArtificialIntelligence.huggingFaceHub]
    ) -> [URL] {
        let hubs = Set(repositoryRoots.map(\.standardizedFileURL))
        var paths: [URL] = []
        for root in roots {
            guard !Task.isCancelled else { break }
            guard isRealDirectory(root) else { continue }
            guard hubs.contains(root.standardizedFileURL) else {
                paths.append(root)
                continue
            }
            let children = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for child in children {
                guard !Task.isCancelled else { break }
                guard child.lastPathComponent.hasPrefix("models--"),
                      isRealDirectory(child),
                      isRealDirectory(child.appending(path: "blobs")) else { continue }
                paths.append(child)
            }
        }
        return paths.sorted { $0.path < $1.path }
    }

    private static func isRealDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return values?.isDirectory == true && values?.isSymbolicLink != true
    }
}
