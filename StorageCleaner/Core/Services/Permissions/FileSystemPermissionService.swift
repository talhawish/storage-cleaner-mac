import Foundation

struct FileSystemPermissionService: StoragePermissionHandling {
    private static let bookmarkKey = "HomeFolderSecurityScopedBookmark"
    // Shared with AppBundleUninstaller so an Applications grant made while inventorying is also
    // available to the uninstall flow, without any Apple Events entitlement or scripting.
    static let applicationsBookmarkKeyPrefix = "ApplicationsFolderSecurityScopedBookmark"
    private static let legacyChildFolders: [HomeChildFolder] = [
        HomeChildFolder(relativePath: "Desktop", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: "Documents", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: "Downloads", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: "Pictures", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: "Movies", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: "Library", directoryHint: .isDirectory),
        HomeChildFolder(relativePath: ".Trash", directoryHint: .isDirectory)
    ]

    private let bookmarkStore: any BookmarkDataStoring
    private let picker: any HomeFolderPicking
    private let applicationsPicker: any ApplicationsFolderPicking
    private let homeDirectory: URL

    init(
        bookmarkStore: any BookmarkDataStoring = UserDefaultsBookmarkDataStore(
            userDefaults: UserDefaults(suiteName: "com.storagecleaner.developer") ?? .standard
        ),
        picker: any HomeFolderPicking = NSOpenPanelHomeFolderPicker(),
        applicationsPicker: any ApplicationsFolderPicking = NSOpenPanelApplicationsFolderPicker(),
        homeDirectory: URL = UserHomeDirectory.url
    ) {
        self.bookmarkStore = bookmarkStore
        self.picker = picker
        self.applicationsPicker = applicationsPicker
        self.homeDirectory = homeDirectory
    }

    func currentStatuses() -> [StoragePermissionStatus] {
        let resolvedHome = resolveBookmarkedHome()
        let homeAccessible = resolvedHome != nil
        var statuses: [StoragePermissionStatus] = [
            StoragePermissionStatus(
                scope: .home,
                url: homeDirectory,
                state: homeAccessible ? .accessible : .denied
            )
        ]

        let scopedFolders: [(StoragePermissionScope, String)] = [
            (.desktop, "Desktop"),
            (.downloads, "Downloads"),
            (.movies, "Movies"),
            (.pictures, "Pictures"),
            (.library, "Library"),
            (.trash, ".Trash")
        ]

        for (scope, relativePath) in scopedFolders {
            let childURL = homeDirectory.appending(path: relativePath, directoryHint: .isDirectory)
            let state: StoragePermissionState = homeAccessible ? .accessible : .denied
            statuses.append(
                StoragePermissionStatus(
                    scope: scope,
                    url: childURL,
                    state: state
                )
            )
        }

        return statuses
    }

    @MainActor
    func requestHomeFolderAccess() -> Bool {
        guard let selectedURL = picker.pickHomeFolder(defaultURL: homeDirectory),
              Self.isHomeFolder(selectedURL, homeDirectory: homeDirectory) else {
            return false
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarkStore.set(bookmark, forKey: Self.bookmarkKey)
            return true
        } catch {
            removeStoredBookmarks()
            return false
        }
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        guard let home = resolveBookmarkedHome() else { return nil }
        let didStartHomeAccess = home.startAccessingSecurityScopedResource()

        // Probe actual directory access while the security scope is active.
        // Bookmark resolution can succeed even when TCC denies access
        // (e.g. user revoked Home Folder permission in System Settings
        // without clearing the bookmark). The opendir-based probe surfaces
        // TCC's EPERM denial, which is the only reliable signal.
        if DirectoryAccessProbe.state(of: home) == .denied {
            if didStartHomeAccess {
                home.stopAccessingSecurityScopedResource()
            }
            removeStoredBookmarks()
            return nil
        }

        var accesses: [SecurityScopedResourceAccess] = []
        accesses.append(SecurityScopedResourceAccess(url: home, didStartAccessing: didStartHomeAccess))

        return SecurityScopedResourceAccess(accesses: accesses)
    }

    @MainActor
    func requestApplicationsFolderAccess(for applicationsFolder: URL) -> Bool {
        guard Self.isSupportedApplicationsFolder(applicationsFolder, homeDirectory: homeDirectory) else {
            return false
        }
        if let existingAccess = beginApplicationsFolderAccess(for: applicationsFolder) {
            existingAccess.stop()
            return true
        }
        guard let selectedURL = applicationsPicker.pickApplicationsFolder(defaultURL: applicationsFolder),
              Self.isApplicationsFolder(selectedURL, expected: applicationsFolder) else {
            return false
        }

        do {
            let bookmark = try selectedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            bookmarkStore.set(
                bookmark,
                forKey: Self.applicationsBookmarkKey(for: applicationsFolder)
            )
            return true
        } catch {
            removeApplicationsBookmark(for: applicationsFolder)
            return false
        }
    }

    func beginApplicationsFolderAccess(for applicationsFolder: URL) -> SecurityScopedResourceAccess? {
        guard Self.isSupportedApplicationsFolder(applicationsFolder, homeDirectory: homeDirectory),
              let applications = resolveBookmarkedApplicationsFolder(for: applicationsFolder) else {
            return nil
        }

        let didStartAccess = applications.startAccessingSecurityScopedResource()
        if DirectoryAccessProbe.state(of: applications) == .denied {
            if didStartAccess {
                applications.stopAccessingSecurityScopedResource()
            }
            removeApplicationsBookmark(for: applicationsFolder)
            return nil
        }

        return SecurityScopedResourceAccess(
            url: applications,
            didStartAccessing: didStartAccess
        )
    }

    static func isHomeFolder(_ url: URL, homeDirectory: URL) -> Bool {
        normalizedPath(for: url) == normalizedPath(for: homeDirectory)
    }

    static func isApplicationsFolder(_ url: URL, expected: URL) -> Bool {
        normalizedPath(for: url) == normalizedPath(for: expected)
    }

    private static func isSupportedApplicationsFolder(
        _ url: URL,
        homeDirectory: URL
    ) -> Bool {
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplications = homeDirectory.appending(path: "Applications", directoryHint: .isDirectory)
        return isApplicationsFolder(url, expected: systemApplications)
            || isApplicationsFolder(url, expected: userApplications)
    }

    private func resolveBookmarkedHome() -> URL? {
        guard let bookmark = bookmarkStore.data(forKey: Self.bookmarkKey) else { return nil }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard Self.isHomeFolder(resolvedURL, homeDirectory: homeDirectory) else {
                removeStoredBookmarks()
                return nil
            }
            if isStale {
                try refreshBookmark(for: resolvedURL)
            }
            return resolvedURL
        } catch {
            removeStoredBookmarks()
            return nil
        }
    }

    private func refreshBookmark(for url: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarkStore.set(bookmark, forKey: Self.bookmarkKey)
    }

    private func resolveBookmarkedApplicationsFolder(for applicationsFolder: URL) -> URL? {
        let key = Self.applicationsBookmarkKey(for: applicationsFolder)
        guard let bookmark = bookmarkStore.data(forKey: key) else { return nil }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL
            guard Self.isApplicationsFolder(resolvedURL, expected: applicationsFolder) else {
                bookmarkStore.removeObject(forKey: key)
                return nil
            }
            if isStale {
                try refreshApplicationsBookmark(for: resolvedURL, applicationsFolder: applicationsFolder)
            }
            return resolvedURL
        } catch {
            bookmarkStore.removeObject(forKey: key)
            return nil
        }
    }

    private func refreshApplicationsBookmark(for url: URL, applicationsFolder: URL) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarkStore.set(bookmark, forKey: Self.applicationsBookmarkKey(for: applicationsFolder))
    }

    private func removeApplicationsBookmark(for applicationsFolder: URL) {
        bookmarkStore.removeObject(forKey: Self.applicationsBookmarkKey(for: applicationsFolder))
    }

    private static func applicationsBookmarkKey(for applicationsFolder: URL) -> String {
        "\(applicationsBookmarkKeyPrefix).\(normalizedPath(for: applicationsFolder))"
    }

    private func removeStoredBookmarks() {
        bookmarkStore.removeObject(forKey: Self.bookmarkKey)
        for folder in Self.legacyChildFolders {
            bookmarkStore.removeObject(forKey: folder.bookmarkKey)
        }
    }

    private static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

private struct HomeChildFolder: Sendable {
    let relativePath: String
    let directoryHint: URL.DirectoryHint

    var bookmarkKey: String {
        "HomeFolderSecurityScopedBookmark.\(relativePath)"
    }
}
