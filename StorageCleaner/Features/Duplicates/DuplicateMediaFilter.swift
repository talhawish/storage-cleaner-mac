import Foundation

/// Media-type filter for duplicate findings.
enum DuplicateMediaFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"
    case documents = "Documents"

    var id: Self { self }

    var kinds: [StorageFindingKind] {
        switch self {
        case .all: [.duplicatePhotos, .duplicateVideos, .duplicateDocuments]
        case .photos: [.duplicatePhotos]
        case .videos: [.duplicateVideos]
        case .documents: [.duplicateDocuments]
        }
    }
}
