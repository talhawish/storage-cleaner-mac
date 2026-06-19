import Foundation

struct FileCandidate: Equatable, Sendable {
    let url: URL
    let bytes: Int64
}

struct FileCollectionResult: Equatable, Sendable {
    let candidates: [FileCandidate]
    let inspectedItemCount: Int
}

struct DuplicateCollectionResult: Equatable, Sendable {
    let groups: [DuplicateGroup]
    let inspectedItemCount: Int
}

extension FileCandidate {
    var displayName: String {
        url.lastPathComponent
    }
}
