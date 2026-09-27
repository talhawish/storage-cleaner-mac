import Foundation

private enum TrashSingleItemResult: Sendable {
    case moved(URL)
    case alreadyMissing
    case failed(any Error)
}

struct TrashMoveResult: Sendable {
    let destinationBySource: [URL: URL]
    let alreadyMissingSources: Set<URL>
    let error: (any Error)?

    init(
        destinationBySource: [URL: URL],
        error: (any Error)?,
        alreadyMissingSources: Set<URL> = []
    ) {
        self.destinationBySource = destinationBySource
        self.alreadyMissingSources = alreadyMissingSources
        self.error = error
    }
}

protocol TrashMoving: Sendable {
    func moveToTrash(_ urls: [URL]) async -> TrashMoveResult
    func moveToTrash(
        _ urls: [URL],
        progress: @escaping @Sendable (Int) -> Void
    ) async -> TrashMoveResult
}

extension TrashMoving {
    func moveToTrash(
        _ urls: [URL],
        progress: @escaping @Sendable (Int) -> Void
    ) async -> TrashMoveResult {
        let result = await moveToTrash(urls)
        progress(urls.count)
        return result
    }

    /// Moves one item and verifies that macOS returned a Trash destination.
    func moveOneToTrash(_ url: URL) async throws {
        let result = await moveToTrash([url])
        let source = url.standardizedFileURL
        let hasDestination = result.destinationBySource.keys.contains { $0.standardizedFileURL == source }
        guard hasDestination || result.alreadyMissingSources.contains(source) else {
            throw result.error ?? CocoaError(.fileWriteUnknown)
        }
    }
}

/// Uses `FileManager.trashItem` to move files to Trash. Moves are bounded so a
/// large selection cannot launch an unbounded number of concurrent filesystem
/// operations, and each completed item can update the cleanup progress.
struct WorkspaceTrashMover: TrashMoving {
    private static let maximumConcurrentMoves = 4

    func moveToTrash(_ urls: [URL]) async -> TrashMoveResult {
        await moveToTrash(urls, progress: { _ in })
    }

    func moveToTrash(
        _ urls: [URL],
        progress: @escaping @Sendable (Int) -> Void
    ) async -> TrashMoveResult {
        guard !urls.isEmpty else {
            return TrashMoveResult(destinationBySource: [:], error: nil)
        }

        var destinationBySource: [URL: URL] = [:]
        var lastError: (any Error)?
        var successfulCount = 0
        var completedCount = 0
        var alreadyMissingSources: Set<URL> = []

        await withTaskGroup(of: (URL, TrashSingleItemResult).self) { group in
            var pending = urls.makeIterator()
            func addNextMove() {
                guard let url = pending.next() else { return }
                group.addTask {
                    guard !Task.isCancelled else {
                        return (url, .failed(CancellationError()))
                    }
                    return (url, Self.trashSingleItem(url, fileManager: FileManager.default))
                }
            }

            for _ in 0..<min(Self.maximumConcurrentMoves, urls.count) {
                addNextMove()
            }

            for await (source, result) in group {
                completedCount += 1
                switch result {
                case let .moved(destination):
                    successfulCount += 1
                    destinationBySource[source.standardizedFileURL] = destination
                case .alreadyMissing:
                    successfulCount += 1
                    alreadyMissingSources.insert(source.standardizedFileURL)
                case let .failed(error):
                    lastError = error
                }
                progress(completedCount)
                addNextMove()
            }
        }

        return TrashMoveResult(
            destinationBySource: destinationBySource,
            error: successfulCount == urls.count ? nil : (lastError ?? CocoaError(.fileWriteUnknown)),
            alreadyMissingSources: alreadyMissingSources
        )
    }

    private static func trashSingleItem(
        _ url: URL,
        fileManager: FileManager
    ) -> TrashSingleItemResult {
        let standardized = url.standardizedFileURL

        do {
            guard try FileItemExistence.attributes(at: standardized, fileManager: fileManager) != nil else {
                return .alreadyMissing
            }
        } catch {
            return .failed(error)
        }

        var resultingURL: NSURL?
        do {
            try fileManager.trashItem(at: standardized, resultingItemURL: &resultingURL)
            guard let destination = resultingURL as URL? else {
                return .failed(CocoaError(.fileWriteUnknown))
            }
            guard try FileItemExistence.attributes(at: standardized, fileManager: fileManager) == nil else {
                return .failed(CocoaError(.fileWriteUnknown))
            }
            return .moved(destination)
        } catch {
            if FileItemExistence.isMissingItemError(error) {
                return .alreadyMissing
            }
            return .failed(error)
        }
    }
}
