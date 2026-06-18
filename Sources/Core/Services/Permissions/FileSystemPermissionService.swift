import Foundation

struct FileSystemPermissionService: StoragePermissionHandling {
    func currentStatuses() -> [StoragePermissionStatus] {
        StoragePermissionScope.allCases.map { scope in
            let url = url(for: scope)
            return StoragePermissionStatus(
                scope: scope,
                url: url,
                state: state(for: url)
            )
        }
    }

    private func url(for scope: StoragePermissionScope) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser

        return switch scope {
        case .home: home
        case .desktop: home.appending(path: "Desktop", directoryHint: .isDirectory)
        case .downloads: home.appending(path: "Downloads", directoryHint: .isDirectory)
        case .movies: home.appending(path: "Movies", directoryHint: .isDirectory)
        case .pictures: home.appending(path: "Pictures", directoryHint: .isDirectory)
        case .library: home.appending(path: "Library", directoryHint: .isDirectory)
        case .trash: home.appending(path: ".Trash", directoryHint: .isDirectory)
        }
    }

    private func state(for url: URL) -> StoragePermissionState {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: url.path) else {
            return .missing
        }

        return fileManager.isReadableFile(atPath: url.path) ? .accessible : .denied
    }
}
