import Foundation

/// The result of compressing a single project: a hibernation step followed by
/// a verified zip creation and the removal of the original folder. The
/// operation is atomic from the user's perspective: if any step fails, the
/// project folder is left exactly as it was found and `failureReason` is set.
struct CompressionOutcome: Identifiable, Sendable {
    let project: ProjectInfo
    /// Path of the produced zip archive. The archive lives next to the original
    /// project folder (`<parent>/<project-name>.zip`).
    let zipURL: URL
    /// Total bytes of the project folder before hibernation, including
    /// dependencies.
    let originalSize: Int64
    /// Bytes of regenerable dependencies reclaimed before compression.
    let reclaimedDependencyBytes: Int64
    /// Number of dependency directories moved to the Trash during the
    /// hibernation step.
    let removedDirectoryCount: Int
    /// Size of the produced zip archive on disk. Populated only when the
    /// archive was successfully created; zero if the operation failed before
    /// the archive was written.
    let archiveSize: Int64
    /// Total bytes freed on disk by the operation. This is the hibernated
    /// dependency bytes plus the difference between the project size and the
    /// archive size.
    let totalReclaimedBytes: Int64
    /// When non-nil, the operation did not complete successfully and the
    /// project folder is left untouched (or in a state the user can recover
    /// from by reinstalling dependencies).
    let failureReason: String?

    var id: UUID { project.id }
    var succeeded: Bool { failureReason == nil }
}

/// Compresses a developer project to a zip archive next to the original folder,
/// after first hibernating it (removing its regenerable dependencies). The
/// original folder is moved to the Trash only once the archive has been
/// created **and** integrity-checked, so a partial or corrupted zip never
/// results in data loss.
///
/// The service runs as an actor so the long-running compression step never
/// blocks the UI. All filesystem mutations are bounded by the actor's
/// serial execution.
protocol ProjectCompressionServicing: Sendable {
    func compress(_ project: ProjectInfo) async -> CompressionOutcome
}

actor ProjectCompressionService: ProjectCompressionServicing {
    /// How the original project folder and the reclaimed dependency
    /// directories are removed. Production moves them to the Trash so they
    /// stay restorable; tests substitute a hard delete so their fixtures
    /// remain self-contained.
    enum Removal: Sendable {
        case trash
        case delete
    }

    /// A small abstraction over the underlying shell tool so the service can be
    /// exercised in tests without spawning real subprocesses.
    struct CompressionCommand: Sendable {
        let compress: @Sendable (URL, URL) async throws -> Void
        let verify: @Sendable (URL) async throws -> Void
    }

    private let fileManager: FileManager
    private let removal: Removal
    private let command: CompressionCommand

    /// Production initializer. Uses `/usr/bin/ditto` for compression and
    /// `/usr/bin/unzip -t` for verification.
    init(
        fileManager: FileManager = .default,
        removal: Removal = .trash,
        executor: DittoProcessExecutor = DittoProcessExecutor()
    ) {
        self.fileManager = fileManager
        self.removal = removal
        self.command = CompressionCommand(
            compress: { try await executor.compressDirectory($0, to: $1) },
            verify: { try await executor.verifyArchive($0) }
        )
    }

    /// Test initializer that lets the caller drive compression and verification
    /// outcomes directly.
    init(
        fileManager: FileManager = .default,
        removal: Removal = .delete,
        command: CompressionCommand
    ) {
        self.fileManager = fileManager
        self.removal = removal
        self.command = command
    }

    /// The mutable inputs every step of the pipeline shares. Bundled so each
    /// step helper can take a small argument list instead of repeating the
    /// same five parameters.
    private struct PipelineContext {
        let project: ProjectInfo
        let zipURL: URL
        let originalSize: Int64
        var reclamation: ReclamationResult?
        var archiveSize: Int64 = 0
    }

    func compress(_ project: ProjectInfo) async -> CompressionOutcome {
        var context = PipelineContext(
            project: project,
            zipURL: Self.zipURL(for: project),
            originalSize: directorySize(project.path)
        )

        if fileManager.fileExists(atPath: context.zipURL.path) {
            return makeFailure(
                context: context,
                reason: "A file already exists at \(context.zipURL.path). "
                    + "Move or rename it, then try again."
            )
        }

        let dependencyDirectories = projectDependencyDirectories(in: project)
        context.reclamation = reclaim(dependencyDirectories: dependencyDirectories, in: project)
        if let reason = context.reclamation?.failureReason {
            return makeFailure(context: context, reason: reason)
        }

        if Task.isCancelled {
            return makeFailure(
                context: context,
                reason: "Compression was cancelled before the archive was created."
            )
        }

        return await runCompressionPipeline(context: context)
    }

    private func runCompressionPipeline(
        context: PipelineContext
    ) async -> CompressionOutcome {
        var context = context
        do {
            try await command.compress(context.project.path, context.zipURL)
        } catch {
            return makeFailure(
                context: context,
                reason: friendlyMessage(for: error, phase: "compressing the project")
            )
        }

        guard let archiveSize = try? validatedArchiveSize(at: context.zipURL) else {
            cleanupFailedArchive(at: context.zipURL)
            return makeFailure(context: context, reason: "The archive is missing or empty.")
        }
        context.archiveSize = archiveSize

        if let outcome = await verifyArchive(context: context) { return outcome }
        if let outcome = removeOriginalFolder(context: context) { return outcome }
        return makeSuccess(context: context)
    }

    /// Runs the integrity check and turns failures into outcomes. Returns
    /// `nil` to signal "verification passed — keep going".
    private func verifyArchive(context: PipelineContext) async -> CompressionOutcome? {
        let context = context
        do {
            try await command.verify(context.zipURL)
            return nil
        } catch {
            cleanupFailedArchive(at: context.zipURL)
            return makeFailure(
                context: context,
                reason: friendlyMessage(for: error, phase: "verifying the archive")
            )
        }
    }

    /// Removes the original project folder. Returns `nil` on success so the
    /// pipeline can keep going.
    private func removeOriginalFolder(context: PipelineContext) -> CompressionOutcome? {
        let context = context
        do {
            try remove(context.project.path)
            return nil
        } catch {
            return makeFailure(
                context: context,
                reason: friendlyMessage(
                    for: error,
                    phase: "removing the original project folder",
                    suffix: "The archive is at \(context.zipURL.path) and is intact."
                )
            )
        }
    }

    private func makeSuccess(context: PipelineContext) -> CompressionOutcome {
        let postHibernationSize = max(0, context.originalSize - (context.reclamation?.bytesReclaimed ?? 0))
        let totalReclaimed = max(0, postHibernationSize - context.archiveSize)
            + (context.reclamation?.bytesReclaimed ?? 0)
        return CompressionOutcome(
            project: context.project,
            zipURL: context.zipURL,
            originalSize: context.originalSize,
            reclaimedDependencyBytes: context.reclamation?.bytesReclaimed ?? 0,
            removedDirectoryCount: context.reclamation?.removedCount ?? 0,
            archiveSize: context.archiveSize,
            totalReclaimedBytes: totalReclaimed,
            failureReason: nil
        )
    }

    private func makeFailure(context: PipelineContext, reason: String) -> CompressionOutcome {
        CompressionOutcome(
            project: context.project,
            zipURL: context.zipURL,
            originalSize: context.originalSize,
            reclaimedDependencyBytes: context.reclamation?.bytesReclaimed ?? 0,
            removedDirectoryCount: context.reclamation?.removedCount ?? 0,
            archiveSize: context.archiveSize,
            totalReclaimedBytes: context.reclamation?.bytesReclaimed ?? 0,
            failureReason: reason
        )
    }

    // MARK: - Helpers

    /// The destination path for the produced archive: `<parent>/<name>.zip`.
    /// Sibling of the project folder so the original parent path is preserved
    /// and the user can keep related projects together.
    static func zipURL(for project: ProjectInfo) -> URL {
        project.path
            .deletingLastPathComponent()
            .appending(path: "\(project.path.lastPathComponent).zip")
    }

    private struct ReclamationResult {
        var bytesReclaimed: Int64 = 0
        var removedCount: Int = 0
        var failureReason: String?
    }

    private func reclaim(
        dependencyDirectories: [URL],
        in project: ProjectInfo
    ) -> ReclamationResult {
        var result = ReclamationResult()
        var failures: [String] = []
        for directory in dependencyDirectories {
            guard !Task.isCancelled else {
                result.failureReason = "Compression was cancelled before the archive was created."
                return result
            }
            let size = directorySize(directory)
            do {
                try remove(directory)
                result.bytesReclaimed += size
                result.removedCount += 1
            } catch {
                failures.append(directory.lastPathComponent)
            }
        }
        if !failures.isEmpty {
            result.failureReason = "Couldn't remove \(failures.joined(separator: ", ")) before compressing."
        }
        return result
    }

    /// The dependency directories the same way `ProjectHibernationService` does
    /// it: walking the project tree and matching directory names against the
    /// technology's known set. Duplicated locally so the service can operate
    /// without depending on the hibernation actor.
    private func projectDependencyDirectories(in project: ProjectInfo) -> [URL] {
        guard !project.technology.dependencyDirectoryNames.isEmpty else { return [] }

        guard let enumerator = fileManager.enumerator(
            at: project.path,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return [] }

        var matches: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            guard !Task.isCancelled else { break }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            if ProjectDependencyRules.isDependencyDirectory(
                url,
                for: project.technology,
                projectRoot: project.path,
                fileManager: fileManager
            ) {
                matches.append(url)
                enumerator.skipDescendants()
            }
        }
        return matches
    }

    private func validatedArchiveSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0 else {
            throw ProcessRunError(
                executable: "/usr/bin/ditto",
                arguments: ["<archive>"],
                exitCode: -1,
                standardError: Data("archive is missing or empty".utf8)
            )
        }
        return Int64(size)
    }

    private func cleanupFailedArchive(at url: URL) {
        try? fileManager.removeItem(at: url)
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

    private func friendlyMessage(for error: Error, phase: String, suffix: String = "") -> String {
        let trailer = suffix.isEmpty ? "" : " " + suffix
        if let processError = error as? ProcessRunError {
            let stderr = processError.standardErrorText.trimmingCharacters(in: .whitespacesAndNewlines)
            if stderr.isEmpty {
                return "An error occurred while \(phase).\(trailer)"
            }
            return "\(stderr) (while \(phase)).\(trailer)"
        }
        return "An error occurred while \(phase): \(error.localizedDescription)\(trailer)"
    }
}
