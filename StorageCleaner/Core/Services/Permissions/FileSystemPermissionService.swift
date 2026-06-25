import Foundation

struct FileSystemPermissionService: StoragePermissionHandling {
    private static let bookmarkKey = "HomeFolderSecurityScopedBookmark"
    private static let scopedChildFolders: [HomeChildFolder] = [
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
        let homeAccessible = resolveBookmarkedHome() != nil
        var statuses: [StoragePermissionStatus] = [
            StoragePermissionStatus(
                scope: .home,
                url: homeDirectory,
                state: homeAccessible ? .accessible : .denied
            )
        ]

        let scopeByRelativePath: [StoragePermissionScope: String] = [
            .desktop: "Desktop",
            .downloads: "Downloads",
            .movies: "Movies",
            .pictures: "Pictures",
            .library: "Library",
            .trash: ".Trash"
        ]

        for (scope, relativePath) in scopeByRelativePath {
            let childFolder = HomeChildFolder(relativePath: relativePath, directoryHint: .isDirectory)
            let resolved = resolveChildBookmark(childFolder, homeDirectory: homeDirectory)
            let state: StoragePermissionState
            if resolved != nil {
                state = .accessible
            } else if bookmarkStore.data(forKey: childFolder.bookmarkKey) != nil {
                state = .denied
            } else {
                state = .missing
            }
            statuses.append(
                StoragePermissionStatus(
                    scope: scope,
                    url: homeDirectory.appending(path: relativePath, directoryHint: .isDirectory),
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
            refreshChildBookmarks(for: selectedURL)
            return true
        } catch {
            removeStoredBookmarks()
            return false
        }
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        guard let home = resolveBookmarkedHome() else { return nil }

        // Probe actual directory access while the security scope is active.
        // Bookmark resolution can succeed even when TCC denies access
        // (e.g. user revoked Home Folder permission in System Settings
        // without clearing the bookmark). The opendir-based probe surfaces
        // TCC's EPERM denial, which is the only reliable signal.
        if DirectoryAccessProbe.state(of: home) == .denied {
            home.stopAccessingSecurityScopedResource()
            removeStoredBookmarks()
            return nil
        }

        var accesses: [SecurityScopedResourceAccess] = []
        // Scope is already started by resolveBookmarkedHome's .withSecurityScope.
        accesses.append(SecurityScopedResourceAccess(url: home, didStartAccessing: true))

        for url in resolveChildBookmarks(homeDirectory: home) {
            // Scope already started by resolveChildBookmark's .withSecurityScope.
            accesses.append(SecurityScopedResourceAccess(url: url, didStartAccessing: true))
        }

        return SecurityScopedResourceAccess(accesses: accesses)
    }

    static func isHomeFolder(_ url: URL, homeDirectory: URL) -> Bool {
        normalizedPath(for: url) == normalizedPath(for: homeDirectory)
    }

    private func resolveChildBookmarks(homeDirectory: URL) -> [URL] {
        Self.scopedChildFolders.compactMap { folder in
            resolveChildBookmark(folder, homeDirectory: homeDirectory)
        }
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

    private func resolveChildBookmark(_ folder: HomeChildFolder, homeDirectory: URL) -> URL? {
        guard let bookmark = bookmarkStore.data(forKey: folder.bookmarkKey) else { return nil }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard isExpectedChildFolder(resolvedURL, folder: folder, homeDirectory: homeDirectory) else {
                bookmarkStore.removeObject(forKey: folder.bookmarkKey)
                return nil
            }
            if isStale {
                try refreshBookmark(for: resolvedURL, key: folder.bookmarkKey)
            }
            return resolvedURL
        } catch {
            bookmarkStore.removeObject(forKey: folder.bookmarkKey)
            return nil
        }
    }

    private func refreshBookmark(for url: URL) throws {
        try refreshBookmark(for: url, key: Self.bookmarkKey)
    }

    private func refreshBookmark(for url: URL, key: String) throws {
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarkStore.set(bookmark, forKey: key)
    }

    private func refreshChildBookmarks(for homeURL: URL) {
        let didStart = homeURL.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                homeURL.stopAccessingSecurityScopedResource()
            }
        }

        for folder in Self.scopedChildFolders {
            let childURL = homeURL.appending(path: folder.relativePath, directoryHint: folder.directoryHint)
            guard FileManager.default.fileExists(atPath: childURL.path) else {
                bookmarkStore.removeObject(forKey: folder.bookmarkKey)
                continue
            }
            do {
                try refreshBookmark(for: childURL, key: folder.bookmarkKey)
            } catch {
                bookmarkStore.removeObject(forKey: folder.bookmarkKey)
            }
        }
    }

    private func isExpectedChildFolder(_ url: URL, folder: HomeChildFolder, homeDirectory: URL) -> Bool {
        Self.normalizedPath(for: url) == Self.normalizedPath(
            for: homeDirectory.appending(path: folder.relativePath, directoryHint: folder.directoryHint)
        )
    }

    private func removeStoredBookmarks() {
        bookmarkStore.removeObject(forKey: Self.bookmarkKey)
        for folder in Self.scopedChildFolders {
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
