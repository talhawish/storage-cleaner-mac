enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case developerStorage
    case largeFiles
    case duplicates
    case cleanupHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .developerStorage: "Developer Storage"
        case .largeFiles: "Large Files"
        case .duplicates: "Duplicates"
        case .cleanupHistory: "Cleanup History"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .developerStorage: "chevron.left.forwardslash.chevron.right"
        case .largeFiles: "doc.badge.ellipsis"
        case .duplicates: "square.on.square"
        case .cleanupHistory: "clock.arrow.circlepath"
        }
    }
}
