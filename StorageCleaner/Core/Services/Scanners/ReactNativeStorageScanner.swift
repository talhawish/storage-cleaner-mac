import Foundation

/// Aggregates per-project React Native build artifacts (`ios/Pods`, `ios/build`,
/// `android/app/build`, `android/.gradle`, `android/build`) across every React
/// Native project discovered under `DependencyPaths.Projects.searchRoots`. The
/// global `~/.gradle` and `~/Library/Android/sdk` caches are *not* included —
/// those are owned by `AndroidStudioStorageScanner` and surfacing them here too
/// would double-count the same bytes in the dashboard.
struct ReactNativeStorageScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .reactNativeArtifacts
    let title = StorageFindingKind.reactNativeArtifacts.title

    private let projectRoots: [URL]
    private let maxDepth: Int
    private let collector: FileSystemCollector
    private let builder: CandidateFindingBuilder

    init(
        projectRoots: [URL] = DependencyPaths.Projects.searchRoots,
        maxDepth: Int = DependencyPaths.Projects.maxDepth,
        collector: FileSystemCollector,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.projectRoots = projectRoots
        self.maxDepth = maxDepth
        self.collector = collector
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        let projects = discoverProjects(in: projectRoots, maxDepth: maxDepth)
        let candidates = Self.deduplicate(projects.flatMap(measureBuildArtifacts))
        let finding = builder.makeFinding(
            kind: kind,
            domain: .mobileDevelopment,
            candidates: candidates,
            safety: .review
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: candidates.count,
            message: finding == nil
                ? "No React Native build artifacts found"
                : Self.message(candidateCount: candidates.count, projectCount: projects.count)
        )
    }

    // MARK: - Discovery

    private func discoverProjects(in roots: [URL], maxDepth: Int) -> [URL] {
        let fileManager = FileManager.default
        var projects: [URL] = []
        var seen = Set<String>()

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard !Task.isCancelled else { break }
            discover(in: root, maxDepth: maxDepth, into: &projects, seen: &seen, fileManager: fileManager)
        }

        return projects
    }

    private func discover(
        in directory: URL,
        maxDepth: Int,
        into projects: inout [URL],
        seen: inout Set<String>,
        fileManager: FileManager
    ) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        let rootDepth = directory.pathComponents.count
        while let item = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }

            if item.pathComponents.count - rootDepth > maxDepth {
                enumerator.skipDescendants()
                continue
            }

            if ProjectDetector.detect(at: item, fileManager: fileManager) == .reactNative {
                let key = item.standardizedFileURL.path
                if seen.insert(key).inserted {
                    projects.append(item)
                }
                enumerator.skipDescendants()
            }
        }
    }

    // MARK: - Measurement

    private func measureBuildArtifacts(in project: URL) -> [FileCandidate] {
        let urls = DependencyPaths.ReactNative.buildSubpaths.map {
            project.appending(path: $0, directoryHint: .isDirectory)
        }
        return collector.collectExistingItems(at: urls).candidates
    }

    private static func deduplicate(_ candidates: [FileCandidate]) -> [FileCandidate] {
        var seen = Set<String>()
        return candidates.filter { candidate in
            seen.insert(candidate.url.standardizedFileURL.path).inserted
        }
    }

    private static func message(candidateCount: Int, projectCount: Int) -> String {
        let suffix = projectCount == 1 ? "" : "s"
        return "Measured \(candidateCount) React Native build locations across \(projectCount) project\(suffix)"
    }
}
