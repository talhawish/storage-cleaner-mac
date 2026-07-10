import Foundation

struct FileSystemPermissionService: StoragePermissionHandling {
    private static let bookmarkKey = "HomeFolderSecurityScopedBookmark"
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
    private let homeDirectory: URL

    init(
        bookmarkStore: any BookmarkDataStoring = UserDefaultsBookmarkDataStore(
            userDefaults: UserDefaults(suiteName: "com.storagecleaner.developer") ?? .standard
        ),
        picker: any HomeFolderPicking = NSOpenPanelHomeFolderPicker(),
        homeDirectory: URL = UserHomeDirectory.url
    ) {
        self.bookmarkStore = bookmarkStore
        self.picker = picker
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

    static func isHomeFolder(_ url: URL, homeDirectory: URL) -> Bool {
        normalizedPath(for: url) == normalizedPath(for: homeDirectory)
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
