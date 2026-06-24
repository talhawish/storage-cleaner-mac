import Foundation

struct PathBuilder: Sendable {
    private let homeDirectory: URL

    init(homeDirectory: URL = UserHomeDirectory.url) {
        self.homeDirectory = homeDirectory
    }

    func home(_ path: String) -> URL {
        homeDirectory.appending(path: path, directoryHint: .inferFromPath)
    }
}
