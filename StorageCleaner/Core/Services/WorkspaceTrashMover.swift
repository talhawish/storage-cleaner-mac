import AppKit
import Foundation

struct TrashMoveResult: Sendable {
    let destinationBySource: [URL: URL]
    let error: (any Error)?
}

protocol TrashMoving: Sendable {
    func moveToTrash(_ urls: [URL]) async -> TrashMoveResult
}

/// Uses the same recoverable Trash operation as Finder for the user-owned paths that pass the
/// cleanup safety policy. Protected app containers never reach this service.
struct WorkspaceTrashMover: TrashMoving {
    func moveToTrash(_ urls: [URL]) async -> TrashMoveResult {
        guard !urls.isEmpty else {
            return TrashMoveResult(destinationBySource: [:], error: nil)
        }

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { destinationBySource, error in
                continuation.resume(
                    returning: TrashMoveResult(
                        destinationBySource: destinationBySource,
                        error: error
                    )
                )
            }
        }
    }
}
