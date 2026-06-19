import Foundation

/// The result of hibernating a single project.
struct HibernationOutcome: Identifiable, Sendable {
    let project: ProjectInfo
    /// Bytes of regenerable dependencies moved to the Trash.
    let reclaimedBytes: Int64
    /// Number of dependency directories removed.
    let removedDirectoryCount: Int
    let failureReason: String?

    var id: UUID { project.id }
    var succeeded: Bool { failureReason == nil }
}

/// Aggregate result of a hibernation request.
struct HibernationSummary: Sendable {
    let outcomes: [HibernationOutcome]

    var succeeded: [HibernationOutcome] { outcomes.filter(\.succeeded) }
    var failed: [HibernationOutcome] { outcomes.filter { !$0.succeeded } }

    /// Bytes reclaimed on disk across every project that hibernated cleanly.
    var reclaimedBytes: Int64 {
        succeeded.reduce(0) { $0 + $1.reclaimedBytes }
    }
}

/// Hibernates a project by moving its regenerable dependency directories
/// (`node_modules`, `target`, `.build`, `.gradle`, `vendor`, …) to the Trash,
/// reclaiming space while leaving every hand-written source file untouched. The
/// project folder itself is **never** removed, and the Trash provides a restore
/// path until the user empties it — the dependencies can otherwise be rebuilt
/// with a single install/build command. Runs off the main actor so the UI is
/// never blocked.
actor ProjectHibernationService {
    /// How a reclaimed dependency directory is removed. Production moves it to
    /// the Trash so it stays restorable; tests substitute a hard delete to keep
    /// their fixtures self-contained and avoid touching the real Trash.
    enum Removal: Sendable {
        case trash
        case delete
    }

    private let fileManager = FileManager.default
    private let removal: Removal

    init(removal: Removal = .trash) {
        self.removal = removal
    }

    func hibernate(_ projects: [ProjectInfo]) async -> HibernationSummary {
        var outcomes: [HibernationOutcome] = []
        for project in projects {
            guard !Task.isCancelled else { break }
            outcomes.append(hibernate(project))
        }
        return HibernationSummary(outcomes: outcomes)
    }

    func hibernate(_ project: ProjectInfo) -> HibernationOutcome {
        guard fileManager.fileExists(atPath: project.path.path) else {
            return outcome(project, reason: "The project folder no longer exists.")
        }

        let directories = dependencyDirectories(in: project)
        guard !directories.isEmpty else {
            return outcome(project, reason: "No regenerable dependencies were found to reclaim.")
        }

        var reclaimed: Int64 = 0
        var removed = 0
        var failures: [String] = []
        for directory in directories {
            guard !Task.isCancelled else { break }
            let size = directorySize(directory)
            do {
                try remove(directory)
                reclaimed += size
                removed += 1
            } catch {
                failures.append(directory.lastPathComponent)
            }
        }

        let reason = failures.isEmpty
            ? nil
            : "Couldn't remove \(failures.joined(separator: ", "))."
        return HibernationOutcome(
            project: project,
            reclaimedBytes: reclaimed,
            removedDirectoryCount: removed,
            failureReason: reason
        )
    }

    // MARK: - Helpers

    private func outcome(_ project: ProjectInfo, reason: String) -> HibernationOutcome {
        HibernationOutcome(project: project, reclaimedBytes: 0, removedDirectoryCount: 0, failureReason: reason)
    }

    private func remove(_ url: URL) throws {
        switch removal {
        case .trash:
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        case .delete:
            try fileManager.removeItem(at: url)
        }
    }

    /// The top-level dependency directories within the project, located by
    /// walking the tree and matching directory names against the technology's
    /// known dependency folders. Once a directory matches its descendants are
    /// skipped, so a nested `node_modules/foo/node_modules` is removed only
    /// once via its parent.
    private func dependencyDirectories(in project: ProjectInfo) -> [URL] {
        let names = project.technology.dependencyDirectoryNames
        guard !names.isEmpty else { return [] }

        // Hidden dependency folders (`.build`, `.gradle`, `.dart_tool`, …) are
        // common, so hidden files are intentionally not skipped here.
        guard let enumerator = fileManager.enumerator(
            at: project.path,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        var matches: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if names.contains(url.lastPathComponent) {
                matches.append(url)
                enumerator.skipDescendants()
            }
        }
        return matches
    }

    /// Total size of the files within a directory, used to report reclaimed
    /// space. Honors cancellation so a large tree never blocks indefinitely.
    private func directorySize(_ directory: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
        ) else { return 0 }

        var total: Int64 = 0
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory != true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
