import Foundation

struct FileSystemPermissionService: StoragePermissionHandling {
    private static let bookmarkKey = "HomeFolderSecurityScopedBookmark"

    private let bookmarkStore: any BookmarkDataStoring
    private let picker: any HomeFolderPicking

    init(
        bookmarkStore: any BookmarkDataStoring = UserDefaultsBookmarkDataStore(userDefaults: .standard),
        picker: any HomeFolderPicking = NSOpenPanelHomeFolderPicker()
    ) {
        self.bookmarkStore = bookmarkStore
        self.picker = picker
    }

    func currentStatuses() -> [StoragePermissionStatus] {
        let home = UserHomeDirectory.url
        return [
            StoragePermissionStatus(
                scope: .home,
                url: home,
                state: resolveBookmarkedHome() == nil ? .denied : .accessible
            )
        ]
    }

    @MainActor
    func requestHomeFolderAccess() -> Bool {
        let home = UserHomeDirectory.url
        guard let selectedURL = picker.pickHomeFolder(defaultURL: home),
              Self.isHomeFolder(selectedURL, homeDirectory: home) else {
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
            bookmarkStore.removeObject(forKey: Self.bookmarkKey)
            return false
        }
    }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        guard let home = resolveBookmarkedHome() else { return nil }
        let didStart = home.startAccessingSecurityScopedResource()
        guard didStart else { return nil }
        return SecurityScopedResourceAccess(url: home, didStartAccessing: didStart)
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
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let home = UserHomeDirectory.url
            guard Self.isHomeFolder(resolvedURL, homeDirectory: home) else {
                bookmarkStore.removeObject(forKey: Self.bookmarkKey)
                return nil
            }
            if isStale {
                try refreshBookmark(for: resolvedURL)
            }
            return resolvedURL
        } catch {
            bookmarkStore.removeObject(forKey: Self.bookmarkKey)
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

    private static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
