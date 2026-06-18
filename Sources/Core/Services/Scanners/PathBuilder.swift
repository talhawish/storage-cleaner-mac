import Foundation

struct PathBuilder: Sendable {
    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func home(_ path: String) -> URL {
        homeDirectory.appending(path: path, directoryHint: .inferFromPath)
    }
}
