import Foundation

struct FileCandidate: Equatable, Sendable {
    let url: URL
    let bytes: Int64
}

extension FileCandidate {
    var displayName: String {
        url.lastPathComponent
    }
}
