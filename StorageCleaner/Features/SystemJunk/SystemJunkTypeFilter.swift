import SwiftUI

enum SystemJunkTypeFilter: String, CaseIterable, Identifiable {
    case all
    case appSupport
    case caches
    case browserCaches
    case containers
    case preferences
    case savedState
    case crashReports

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .appSupport: "App Data"
        case .caches: "Caches"
        case .browserCaches: "Web Caches"
        case .containers: "Containers"
        case .preferences: "Preferences"
        case .savedState: "Saved State"
        case .crashReports: "Crash Reports"
        }
    }

    var sectionTitle: String {
        switch self {
        case .all: "All orphaned & stale data"
        case .appSupport: "Orphaned app data"
        case .caches: "Orphaned app caches"
        case .browserCaches: "Browser & web caches"
        case .containers: "Orphaned app containers"
        case .preferences: "Orphaned app preferences"
        case .savedState: "Orphaned saved state"
        case .crashReports: "Old crash reports"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "trash.slash.fill"
        case .appSupport: "externaldrive.fill"
        case .caches: "internaldrive.fill"
        case .browserCaches: "globe"
        case .containers: "shippingbox.fill"
        case .preferences: "slider.horizontal.3"
        case .savedState: "macwindow.and.cursorarrow"
        case .crashReports: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: AppTheme.rose
        case .appSupport: AppTheme.rose
        case .caches: AppTheme.orange
        case .browserCaches: AppTheme.accent
        case .containers: AppTheme.violet
        case .preferences: AppTheme.indigo
        case .savedState: AppTheme.teal
        case .crashReports: AppTheme.amber
        }
    }

    func contains(_ kind: StorageFindingKind) -> Bool {
        if self == .all {
            return Self.filter(for: kind) != .all
        }
        return Self.filter(for: kind) == self
    }

    static func filter(for kind: StorageFindingKind) -> SystemJunkTypeFilter {
        switch kind {
        case .orphanedAppSupport: .appSupport
        case .orphanedAppCaches: .caches
        case .browserCaches: .browserCaches
        case .orphanedAppContainers: .containers
        case .orphanedAppPreferences: .preferences
        case .orphanedSavedApplicationState: .savedState
        case .oldCrashReports: .crashReports
        default: .all
        }
    }
}
