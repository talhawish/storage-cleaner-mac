/// A selectable item in the sidebar.
enum SidebarItem: Hashable, Identifiable {
    case section(AppSection)

    var id: String {
        switch self {
        case let .section(section): "section.\(section.rawValue)"
        }
    }

    /// The underlying `AppSection` for the selected sidebar item.
    var section: AppSection {
        switch self {
        case let .section(section): section
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case projectActivity
    case apps
    case developerStorage
    case docker
    case simulatorsEmulators
    case aiModels
    case largeFiles
    case largeFolders
    case cliPrograms
    case screenshotsAndRecordings
    case duplicates
    case leftovers
    case systemJunk
    case cleanupHistory
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .projectActivity: "Project Activity"
        case .apps: "Applications"
        case .developerStorage: "Developer Storage"
        case .docker: "Docker"
        case .simulatorsEmulators: "Simulators & Emulators"
        case .aiModels: "AI Models"
        case .largeFiles: "Large Files"
        case .largeFolders: "Other Storage"
        case .cliPrograms: "CLI Programs & Toolchains"
        case .screenshotsAndRecordings: "Screenshots & Recordings"
        case .duplicates: "Duplicates"
        case .leftovers: "Leftovers"
        case .systemJunk: "System Junk"
        case .cleanupHistory: "Cleanup History"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .projectActivity: "clock.badge.checkmark"
        case .apps: "app.badge.fill"
        case .developerStorage: "chevron.left.forwardslash.chevron.right"
        case .docker: "shippingbox.fill"
        case .simulatorsEmulators: "iphone.gen3"
        case .aiModels: "sparkles"
        case .largeFiles: "doc.badge.ellipsis"
        case .largeFolders: "folder.badge.questionmark"
        case .cliPrograms: "terminal.fill"
        case .screenshotsAndRecordings: "camera.viewfinder"
        case .duplicates: "square.on.square"
        case .leftovers: "archivebox.fill"
        case .systemJunk: "trash.slash.fill"
        case .cleanupHistory: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }

    var filterKinds: [StorageFindingKind] {
        switch self {
        case .docker: [.dockerArtifacts]
        case .aiModels: [.aiModelCaches, .localAIModels]
        case .largeFiles: [.largeFiles, .largeVideos, .largePhotos]
        case .largeFolders: [.largeFolders]
        case .cliPrograms: [.cliApps]
        case .screenshotsAndRecordings: [.screenshots, .screenRecordings]
        case .leftovers: [.installerLeftovers, .androidPackages]
        case .systemJunk: [
            .orphanedAppSupport,
            .orphanedAppCaches,
            .orphanedAppContainers,
            .orphanedAppPreferences,
            .orphanedSavedApplicationState,
            .oldCrashReports,
            .browserCaches
        ]
        default: []
        }
    }
}
