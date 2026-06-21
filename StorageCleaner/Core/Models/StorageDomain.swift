import Foundation

enum StorageDomain: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleDevelopment
    case webDevelopment
    case containers
    case mobileDevelopment
    case artificialIntelligence
    case media
    case photos
    case documents
    case screenshots
    case browserData
    case trash
    case cliTooling
    case leftovers
    case systemJunk
    case otherCaches

    var id: Self { self }

    var title: String {
        switch self {
        case .appleDevelopment: "Apple Development"
        case .webDevelopment: "Web Development"
        case .containers: "Containers"
        case .mobileDevelopment: "Mobile Development"
        case .artificialIntelligence: "AI & Machine Learning"
        case .media: "Large Media"
        case .photos: "Photos"
        case .documents: "Documents"
        case .screenshots: "Screenshots"
        case .browserData: "Browser Data"
        case .trash: "Trash"
        case .cliTooling: "CLI Tooling"
        case .leftovers: "Leftovers"
        case .systemJunk: "System Junk"
        case .otherCaches: "Other Caches"
        }
    }

    var symbolName: String {
        switch self {
        case .appleDevelopment: "hammer.fill"
        case .webDevelopment: "globe"
        case .containers: "shippingbox.fill"
        case .mobileDevelopment: "apps.iphone"
        case .artificialIntelligence: "sparkles"
        case .media: "video.fill"
        case .photos: "photo.stack.fill"
        case .documents: "doc.on.doc.fill"
        case .screenshots: "camera.viewfinder"
        case .browserData: "safari.fill"
        case .trash: "trash.fill"
        case .cliTooling: "terminal.fill"
        case .leftovers: "archivebox.fill"
        case .systemJunk: "trash.slash.fill"
        case .otherCaches: "externaldrive.fill"
        }
    }

    var accentColor: StorageAccentColor {
        switch self {
        case .appleDevelopment: .blue
        case .webDevelopment: .cyan
        case .containers: .violet
        case .mobileDevelopment: .mint
        case .artificialIntelligence: .orange
        case .media: .pink
        case .photos: .rose
        case .documents: .cyan
        case .screenshots: .indigo
        case .browserData: .teal
        case .trash: .gray
        case .cliTooling: .teal
        case .leftovers: .amber
        case .systemJunk: .rose
        case .otherCaches: .secondary
        }
    }
}

enum StorageAccentColor: Sendable {
    case blue
    case cyan
    case mint
    case orange
    case pink
    case rose
    case indigo
    case teal
    case violet
    case amber
    case gray
    case secondary
}
