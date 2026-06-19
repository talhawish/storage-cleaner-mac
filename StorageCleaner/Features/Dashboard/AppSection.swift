/// A selectable item in the sidebar. Static `section`s coexist with dynamic `developerDomain`
/// rows that appear only when a scan detects storage in that domain.
enum SidebarItem: Hashable, Identifiable {
    case section(AppSection)
    case developerDomain(StorageDomain)

    var id: String {
        switch self {
        case let .section(section): "section.\(section.rawValue)"
        case let .developerDomain(domain): "domain.\(domain.rawValue)"
        }
    }

    /// The underlying `AppSection` when this item is a static section, else `nil`.
    var section: AppSection? {
        if case let .section(section) = self { return section }
        return nil
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case projectActivity
    case apps
    case developerStorage
    case runtimeVersions
    case largeFiles
    case cliPrograms
    case screenshotsAndRecordings
    case duplicates
    case leftovers
    case cleanupHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .projectActivity: "Project Activity"
        case .apps: "Applications"
        case .developerStorage: "Developer Storage"
        case .runtimeVersions: "Runtime Versions"
        case .largeFiles: "Large Files"
        case .cliPrograms: "CLI Programs & Toolchains"
        case .screenshotsAndRecordings: "Screenshots & Recordings"
        case .duplicates: "Duplicates"
        case .leftovers: "Leftovers"
        case .cleanupHistory: "Cleanup History"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .projectActivity: "clock.badge.checkmark"
        case .apps: "app.badge.fill"
        case .developerStorage: "chevron.left.forwardslash.chevron.right"
        case .runtimeVersions: "square.stack.3d.up.fill"
        case .largeFiles: "doc.badge.ellipsis"
        case .cliPrograms: "terminal.fill"
        case .screenshotsAndRecordings: "camera.viewfinder"
        case .duplicates: "square.on.square"
        case .leftovers: "archivebox.fill"
        case .cleanupHistory: "clock.arrow.circlepath"
        }
    }

    var filterKinds: [StorageFindingKind] {
        switch self {
        case .largeFiles: [.largeFiles, .largeVideos, .largePhotos]
        case .cliPrograms: [.cliApps]
        case .runtimeVersions: [.runtimeVersions]
        case .screenshotsAndRecordings: [.screenshots, .screenRecordings]
        case .leftovers: [.installerLeftovers, .androidPackages]
        default: []
        }
    }
}
