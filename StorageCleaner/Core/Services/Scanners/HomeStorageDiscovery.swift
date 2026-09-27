import Foundation

/// Reusable, per-scan index for large unclassified folders and local model weights.
/// One hidden-file-aware walk feeds both findings so these categories do not each
/// traverse the entire Home folder independently.
actor HomeStorageDiscoveryCache {
    private let policy: HomeStorageDiscoveryPolicy
    private var discoveryTask: Task<HomeStorageDiscoveryResult, Never>?
    private var didReportInspectedItemCount = false

    init(policy: HomeStorageDiscoveryPolicy = .live) {
        self.policy = policy
    }

    func beginScan() {
        discoveryTask?.cancel()
        discoveryTask = nil
        didReportInspectedItemCount = false
    }

    func endScan() {
        discoveryTask?.cancel()
        discoveryTask = nil
        didReportInspectedItemCount = false
    }

    func discover() async -> HomeStorageDiscoveryReport {
        guard !Task.isCancelled else {
            return HomeStorageDiscoveryReport(result: .empty, inspectedItemCount: 0)
        }
        let task: Task<HomeStorageDiscoveryResult, Never>
        if let discoveryTask {
            task = discoveryTask
        } else {
            let policy = self.policy
            task = Task.detached(priority: .utility) {
                HomeStorageDiscoveryIndex.scan(policy: policy)
            }
            discoveryTask = task
        }
        let result = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        guard !Task.isCancelled else {
            return HomeStorageDiscoveryReport(result: .empty, inspectedItemCount: 0)
        }
        return report(result)
    }

    private func report(_ result: HomeStorageDiscoveryResult) -> HomeStorageDiscoveryReport {
        guard !didReportInspectedItemCount else {
            return HomeStorageDiscoveryReport(result: result, inspectedItemCount: 0)
        }
        didReportInspectedItemCount = true
        return HomeStorageDiscoveryReport(result: result, inspectedItemCount: result.inspectedItemCount)
    }
}

struct HomeStorageDiscoveryResult: Sendable {
    static let empty = HomeStorageDiscoveryResult(largeFolders: [], localAIModels: [], inspectedItemCount: 0)
    let largeFolders: [FileCandidate]
    let localAIModels: [FileCandidate]
    let inspectedItemCount: Int
    var unreadableItemCount: Int = 0
}

struct HomeStorageDiscoveryReport: Sendable {
    let result: HomeStorageDiscoveryResult
    let inspectedItemCount: Int
}

private enum HomeStorageDiscoveryIndex {
    private struct DirectoryFrame {
        let url: URL
        let depth: Int
        let isPruned: Bool
        var bytes: Int64 = 0
        var blocksCandidate: Bool = false
        var containsModel: Bool = false
        var candidates: [FileCandidate] = []
    }

    private struct DirectoryEntry {
        let url: URL
        let values: URLResourceValues?
    }

    private struct WalkState {
        var directories: [DirectoryFrame] = []
        var folderCandidates: [FileCandidate] = []
        var modelCandidates: [FileCandidate] = []
        var inspectedItemCount = 0
    }

    /// Accessed only by the synchronous enumeration and its error callback.
    private final class ReadFailures {
        var pendingPaths: [String] = []
        var count = 0

        func record(_ url: URL) {
            pendingPaths.append(url.standardizedFileURL.path)
            count += 1
        }
    }

    private struct WalkContext {
        let enumerator: FileManager.DirectoryEnumerator
        let failures: ReadFailures
        let excludedFolderRoots: [String]
        let excludedModelRoots: [String]
        let policy: HomeStorageDiscoveryPolicy
    }

    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .isPackageKey
    ]

    static func scan(policy: HomeStorageDiscoveryPolicy) -> HomeStorageDiscoveryResult {
        let root = policy.root.standardizedFileURL
        let excludedFolderRoots = normalizedPaths(
            policy.excludedFolderRoots + policy.excludedModelRoots,
            under: root
        )
        let excludedModelRoots = normalizedPaths(policy.excludedModelRoots, under: root)
        let manager = FileManager.default
        let failures = ReadFailures()
        guard manager.fileExists(atPath: root.path),
              let enumerator = manager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [],
                errorHandler: { url, _ in
                    failures.record(url)
                    return !Task.isCancelled
                }
              ) else {
            return HomeStorageDiscoveryResult(largeFolders: [], localAIModels: [], inspectedItemCount: 0)
        }

        return walk(
            enumerator: enumerator,
            failures: failures,
            excludedFolderRoots: excludedFolderRoots,
            excludedModelRoots: excludedModelRoots,
            policy: policy
        )
    }

    private static func walk(
        enumerator: FileManager.DirectoryEnumerator,
        failures: ReadFailures,
        excludedFolderRoots: [String],
        excludedModelRoots: [String],
        policy: HomeStorageDiscoveryPolicy
    ) -> HomeStorageDiscoveryResult {
        var state = WalkState()
        let context = WalkContext(
            enumerator: enumerator,
            failures: failures,
            excludedFolderRoots: excludedFolderRoots,
            excludedModelRoots: excludedModelRoots,
            policy: policy
        )
        while !Task.isCancelled {
            let entry = nextEntry(from: enumerator)
            if let entry, entry.values == nil { failures.record(entry.url) }
            blockIncompleteDirectories(failures: failures, state: &state)
            guard let entry else { break }
            state.inspectedItemCount += 1
            inspect(entry, context: context, state: &state)
        }

        var result = result(from: state, policy: policy, wasCancelled: Task.isCancelled)
        result.unreadableItemCount = failures.count
        return result
    }

    private static func blockIncompleteDirectories(failures: ReadFailures, state: inout WalkState) {
        guard !failures.pendingPaths.isEmpty else { return }
        for index in state.directories.indices {
            let root = state.directories[index].url.path
            if failures.pendingPaths.contains(where: { pathIsInside($0, roots: [root]) }) {
                state.directories[index].blocksCandidate = true
            }
        }
        failures.pendingPaths.removeAll(keepingCapacity: true)
    }

    private static func nextEntry(from enumerator: FileManager.DirectoryEnumerator) -> DirectoryEntry? {
        autoreleasepool {
            guard let url = enumerator.nextObject() as? URL else { return nil }
            return DirectoryEntry(url: url, values: try? url.resourceValues(forKeys: resourceKeys))
        }
    }

    private static func inspect(
        _ entry: DirectoryEntry,
        context: WalkContext,
        state: inout WalkState
    ) {
        guard let values = entry.values else { return }
        let isDirectory = values.isDirectory == true
        if values.isSymbolicLink == true {
            if isDirectory {
                appendPrunedDirectory(entry.url, context: context, state: &state)
            }
            return
        }

        if isDirectory {
            inspectDirectory(
                entry.url,
                isPackage: values.isPackage == true,
                context: context,
                state: &state
            )
        } else {
            inspectFile(
                entry.url,
                isRegularFile: values.isRegularFile == true,
                context: context,
                state: &state
            )
        }
    }

    private static func inspectDirectory(
        _ url: URL,
        isPackage: Bool,
        context: WalkContext,
        state: inout WalkState
    ) {
        finishDirectories(
            beforeDepth: url.pathComponents.count,
            stack: &state.directories,
            candidates: &state.folderCandidates,
            policy: context.policy
        )

        let path = url.standardizedFileURL.path
        let isExcluded = pathIsInside(path, roots: context.excludedFolderRoots)
        let isModelExcluded = pathIsInside(path, roots: context.excludedModelRoots)
        let isGenerated = isGeneratedDirectory(url)
        let isModel = isModelBundle(url)
        if isModel, !isModelExcluded {
            collectModelBundle(url, policy: context.policy, state: &state)
        }

        let isPruned = isExcluded || isGenerated || isModel || isPackage
        state.directories.append(DirectoryFrame(
            url: url.standardizedFileURL,
            depth: url.pathComponents.count,
            isPruned: isPruned,
            blocksCandidate: isPruned,
            containsModel: isModel
        ))
        if isModelExcluded || isGenerated || isModel || isPackage {
            context.enumerator.skipDescendants()
        }
    }

    private static func inspectFile(
        _ url: URL,
        isRegularFile: Bool,
        context: WalkContext,
        state: inout WalkState
    ) {
        let parentDepth = url.deletingLastPathComponent().pathComponents.count
        finishDirectories(
            beforeDepth: parentDepth + 1,
            stack: &state.directories,
            candidates: &state.folderCandidates,
            policy: context.policy
        )
        guard isRegularFile else { return }
        let format = LocalAIModelFormat(url: url)
        let canCountFolderBytes = state.directories.last?.isPruned == false
        // Broad project/media roots are walked only to find models. Do not ask
        // the filesystem for allocated sizes of millions of unrelated files.
        guard canCountFolderBytes || format != nil else { return }
        let values = try? url.resourceValues(forKeys: FileSystemItemSizer.resourceKeys)
        guard let values else {
            context.failures.record(url)
            return
        }
        let bytes = FileSystemItemSizer.allocatedSize(from: values)
        guard bytes > 0 else { return }
        let path = url.path
        if let format,
           !pathIsInside(path, roots: context.excludedModelRoots),
           format.isLikelyModel(
               at: url,
               bytes: bytes,
               defaultMinimum: context.policy.minimumModelBytes
           ) {
            state.modelCandidates.retainLargest(
                FileCandidate(url: url.standardizedFileURL, bytes: bytes),
                limit: context.policy.maximumModelCandidates
            )
            if let parentIndex = state.directories.indices.last {
                state.directories[parentIndex].blocksCandidate = true
                state.directories[parentIndex].containsModel = true
            }
            return
        }

        guard canCountFolderBytes,
              let parentIndex = state.directories.indices.last,
              state.directories[parentIndex].url.path == url.deletingLastPathComponent().standardizedFileURL.path else {
            return
        }
        state.directories[parentIndex].bytes = adding(bytes, to: state.directories[parentIndex].bytes)
    }

    private static func collectModelBundle(
        _ url: URL,
        policy: HomeStorageDiscoveryPolicy,
        state: inout WalkState
    ) {
        let bytes = FileSystemItemSizer.allocatedSize(of: url)
        guard bytes >= policy.minimumModelBytes else { return }
        state.modelCandidates.retainLargest(
            FileCandidate(url: url.standardizedFileURL, bytes: bytes),
            limit: policy.maximumModelCandidates
        )
    }

    private static func appendPrunedDirectory(
        _ url: URL,
        context: WalkContext,
        state: inout WalkState
    ) {
        finishDirectories(
            beforeDepth: url.pathComponents.count,
            stack: &state.directories,
            candidates: &state.folderCandidates,
            policy: context.policy
        )
        state.directories.append(DirectoryFrame(
            url: url.standardizedFileURL,
            depth: url.pathComponents.count,
            isPruned: true,
            blocksCandidate: true
        ))
        context.enumerator.skipDescendants()
    }

    private static func result(
        from state: WalkState,
        policy: HomeStorageDiscoveryPolicy,
        wasCancelled: Bool
    ) -> HomeStorageDiscoveryResult {
        guard !wasCancelled else {
            return HomeStorageDiscoveryResult(
                largeFolders: [],
                localAIModels: [],
                inspectedItemCount: state.inspectedItemCount
            )
        }

        var completed = state
        finishDirectories(
            beforeDepth: 0,
            stack: &completed.directories,
            candidates: &completed.folderCandidates,
            policy: policy
        )
        return HomeStorageDiscoveryResult(
            largeFolders: largestNonOverlappingFolders(
                completed.folderCandidates,
                limit: policy.maximumFolderCandidates
            ),
            localAIModels: completed.modelCandidates.sorted(by: largestFirst),
            inspectedItemCount: completed.inspectedItemCount
        )
    }

    private static func largestNonOverlappingFolders(
        _ candidates: [FileCandidate],
        limit: Int
    ) -> [FileCandidate] {
        Array(candidates.sorted(by: largestFirst).prefix(max(0, limit)))
    }

    private static func largestFirst(_ lhs: FileCandidate, _ rhs: FileCandidate) -> Bool {
        lhs.bytes == rhs.bytes ? lhs.url.path < rhs.url.path : lhs.bytes > rhs.bytes
    }

    private static func finishDirectories(
        beforeDepth depth: Int,
        stack: inout [DirectoryFrame],
        candidates: inout [FileCandidate],
        policy: HomeStorageDiscoveryPolicy
    ) {
        while let frame = stack.last, depth == 0 || frame.depth >= depth {
            _ = stack.popLast()
            let completed: [FileCandidate]
            if !frame.isPruned,
               !frame.blocksCandidate,
               !frame.containsModel,
               frame.bytes >= policy.minimumFolderBytes {
                completed = [FileCandidate(url: frame.url, bytes: frame.bytes)]
            } else {
                completed = frame.candidates
            }

            // Resolve overlaps inside each subtree before applying the cap. A
            // deep ancestor chain must not crowd unrelated folders out of results.
            guard let parentIndex = stack.indices.last else {
                for candidate in completed {
                    candidates.retainLargest(candidate, limit: policy.maximumFolderCandidates)
                }
                continue
            }
            for candidate in completed {
                stack[parentIndex].candidates.retainLargest(candidate, limit: policy.maximumFolderCandidates)
            }
            if !frame.isPruned {
                stack[parentIndex].bytes = adding(frame.bytes, to: stack[parentIndex].bytes)
            }
            if frame.isPruned || frame.blocksCandidate {
                stack[parentIndex].blocksCandidate = true
            }
            if frame.containsModel {
                stack[parentIndex].containsModel = true
            }
        }
    }

    private static func normalizedPaths(_ urls: [URL], under root: URL) -> [String] {
        urls.map { $0.standardizedFileURL.path }
            .filter { pathIsInside($0, roots: [root.path]) }
    }

    private static func adding(_ value: Int64, to total: Int64) -> Int64 {
        let addition = total.addingReportingOverflow(value)
        return addition.overflow ? Int64.max : addition.partialValue
    }

    private static func pathIsInside(_ path: String, roots: [String]) -> Bool {
        roots.contains { root in
            path == root || path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
    }

    private static func isGeneratedDirectory(_ url: URL) -> Bool {
        HomeStorageDiscoveryPolicy.generatedDirectoryNames.contains(url.lastPathComponent)
    }

    private static func isModelBundle(_ url: URL) -> Bool {
        LocalAIModelFormat(url: url)?.isBundle == true
    }
}
