import Foundation

struct StoragePermissionStatus: Equatable, Sendable, Identifiable {
    let scope: StoragePermissionScope
    let url: URL
    let state: StoragePermissionState

    var id: StoragePermissionScope { scope }
}

enum StoragePermissionScope: String, CaseIterable, Sendable {
    case home
    case desktop
    case downloads
    case movies
    case pictures
    case library
    case trash

    var title: String {
        switch self {
        case .home: "Home Folder"
        case .desktop: "Desktop"
        case .downloads: "Downloads"
        case .movies: "Movies"
        case .pictures: "Pictures"
        case .library: "Library"
        case .trash: "Trash"
        }
    }
}

enum StoragePermissionState: Equatable, Sendable {
    case accessible
    case missing
    case denied

    var guidance: String {
        switch self {
        case .accessible: "Accessible"
        case .missing: "Folder does not exist"
        case .denied: "Needs Full Disk Access in System Settings"
        }
    }
}
