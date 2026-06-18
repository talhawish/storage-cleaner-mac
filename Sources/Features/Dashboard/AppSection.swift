enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case projectActivity
    case apps
    case developerStorage
    case largeFiles
    case cliPrograms
    case screenshotsAndRecordings
    case duplicates
    case cleanupHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .projectActivity: "Project Activity"
        case .apps: "Applications"
        case .developerStorage: "Developer Storage"
        case .largeFiles: "Large Files"
        case .cliPrograms: "CLI Programs"
        case .screenshotsAndRecordings: "Screenshots & Recordings"
        case .duplicates: "Duplicates"
        case .cleanupHistory: "Cleanup History"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .projectActivity: "clock.badge.checkmark"
        case .apps: "app.badge.fill"
        case .developerStorage: "chevron.left.forwardslash.chevron.right"
        case .largeFiles: "doc.badge.ellipsis"
        case .cliPrograms: "terminal.fill"
        case .screenshotsAndRecordings: "camera.viewfinder"
        case .duplicates: "square.on.square"
        case .cleanupHistory: "clock.arrow.circlepath"
        }
    }

    var filterKinds: [StorageFindingKind] {
        switch self {
        case .cliPrograms: [.cliApps]
        case .screenshotsAndRecordings: [.screenshots, .screenRecordings]
        default: []
        }
    }
}
