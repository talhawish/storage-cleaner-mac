import AppKit
import Foundation

enum AppBundleUninstallerError: LocalizedError, Sendable {
    case unsupportedLocation(URL)
    case applicationsAccessNotGranted(URL)
    case selectedLocationDoesNotAuthorizeTrash(URL)
    case authorizationRequired(URL)
    case workspaceRecycleFailed(URL, String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedLocation(url):
            "Refusing to move \(url.path) to Trash because it is not an application bundle in an Applications folder."
        case let .applicationsAccessNotGranted(url):
            "Storage Cleaner needs access to /Applications to move \(url.lastPathComponent) to Trash."
        case let .selectedLocationDoesNotAuthorizeTrash(url):
            "The selected location did not grant access to move \(url.lastPathComponent) to Trash."
        case let .authorizationRequired(url):
            "\(url.lastPathComponent) needs macOS administrator authorization before it can be moved to Trash."
        case let .workspaceRecycleFailed(url, message):
            "The macOS Trash operation did not move \(url.lastPathComponent): \(message)"
        }
    }
}

struct AppBundleUninstaller: Sendable {
    var moveToTrashDirectly: @Sendable (URL) async throws -> Void
    var moveToTrashWithUserSelectedAccess: @Sendable (URL) async throws -> Void
    var moveToTrashWithWorkspace: @Sendable (URL) async throws -> Void

    func uninstall(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        guard Self.supportsAppTrashRemoval(for: appURL) else {
            throw AppBundleUninstallerError.unsupportedLocation(appURL)
        }

        do {
            try await moveToTrashDirectly(appURL)
        } catch {
            guard Self.isPermissionError(error) else { throw error }
            do {
                try await moveToTrashWithUserSelectedAccess(appURL)
            } catch {
                guard Self.isPermissionError(error) || Self.isAuthorizationRequired(error) else {
                    throw error
                }
                try await moveToTrashWithWorkspace(appURL)
            }
        }
    }
}

extension AppBundleUninstaller {
    private static let applicationsBookmarkKeyPrefix = FileSystemPermissionService.applicationsBookmarkKeyPrefix
    private static let bookmarkStore: any BookmarkDataStoring = UserDefaultsBookmarkDataStore(
        userDefaults: UserDefaults(suiteName: "com.storagecleaner.developer") ?? .standard
    )

    static let live = AppBundleUninstaller(
        moveToTrashDirectly: { url in
            try trashWithFileManager(url)
        },
        moveToTrashWithUserSelectedAccess: { url in
            try await trashWithUserSelectedApplicationsAccess(url)
        },
        moveToTrashWithWorkspace: { url in
            try await trashWithWorkspace(url)
        }
    )

    static func supportsAppTrashRemoval(for url: URL) -> Bool {
        let appURL = url.standardizedFileURL
        guard appURL.pathExtension.lowercased() == "app" else { return false }

        let allowedRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            UserHomeDirectory.url.appendingPathComponent(
                "Applications",
                isDirectory: true
            )
        ]

        let parent = appURL.deletingLastPathComponent()
            .standardizedFileURL
            .resolvingSymlinksInPath()
        return allowedRoots.contains { root in
            parent == root.standardizedFileURL.resolvingSymlinksInPath()
        }
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            let code = CocoaError.Code(rawValue: nsError.code)
            if code == .fileWriteNoPermission || code == .fileReadNoPermission {
                return true
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == EACCES || nsError.code == EPERM
        }
        return false
    }

    static func isAuthorizationRequired(_ error: Error) -> Bool {
        guard let appError = error as? AppBundleUninstallerError,
              case .authorizationRequired = appError else {
            return false
        }
        return true
    }

    private static func trashWithFileManager(_ url: URL) throws {
        var resultingItemURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemURL)
    }

    @MainActor
    private static func trashWithUserSelectedApplicationsAccess(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        let applicationsFolder = containingApplicationsFolder(for: appURL)

        if let bookmarkedAccessURL = resolveBookmarkedApplicationsFolder(for: applicationsFolder),
           appURL.isDescendant(of: bookmarkedAccessURL) {
            do {
                try trash(appURL, withAccessTo: bookmarkedAccessURL)
            } catch {
                guard Self.isPermissionError(error) else { throw error }
                throw error
            }
            return
        }

        guard let accessURL = requestApplicationsFolderAccess(for: appURL) else {
            throw AppBundleUninstallerError.applicationsAccessNotGranted(appURL)
        }

        guard appURL.isDescendant(of: accessURL) || appURL == accessURL else {
            throw AppBundleUninstallerError.selectedLocationDoesNotAuthorizeTrash(appURL)
        }

        try storeApplicationsFolderBookmark(accessURL, for: applicationsFolder)
        do {
            try trash(appURL, withAccessTo: accessURL)
        } catch {
            guard Self.isPermissionError(error) else { throw error }
            throw error
        }
    }

    /// Uses AppKit's Finder-style recycle operation for bundles that need more than a
    /// direct security-scoped FileManager move. No Apple Events or scripting exception is
    /// needed for this API. If macOS still requires administrator authorization, the
    /// caller presents the existing guidance to complete the move in Finder.
    @MainActor
    private static func trashWithWorkspace(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        let applicationsFolder = containingApplicationsFolder(for: appURL)
        let result: TrashMoveResult

        if let accessURL = resolveBookmarkedApplicationsFolder(for: applicationsFolder),
           appURL.isDescendant(of: accessURL) {
            let didStartAccess = accessURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    accessURL.stopAccessingSecurityScopedResource()
                }
            }
            result = await WorkspaceTrashMover().moveToTrash([appURL])
        } else {
            result = await WorkspaceTrashMover().moveToTrash([appURL])
        }

        guard result.destinationBySource[appURL] != nil else {
            let error = result.error ?? CocoaError(.fileWriteUnknown)
            if Self.isPermissionError(error) {
                throw AppBundleUninstallerError.authorizationRequired(appURL)
            }
            throw AppBundleUninstallerError.workspaceRecycleFailed(
                appURL,
                error.localizedDescription
            )
        }
    }

    private static func trash(_ appURL: URL, withAccessTo accessURL: URL) throws {
        let didStartAccess = accessURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                accessURL.stopAccessingSecurityScopedResource()
            }
        }

        guard appURL.isDescendant(of: accessURL) || appURL == accessURL else {
            throw AppBundleUninstallerError.selectedLocationDoesNotAuthorizeTrash(appURL)
        }

        try trashWithFileManager(appURL)
    }

    @MainActor
    private static func requestApplicationsFolderAccess(for appURL: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Allow Storage Cleaner to access Applications so it can move "
            + "\(appURL.lastPathComponent) to Trash."
        panel.prompt = "Allow Access"
        panel.directoryURL = containingApplicationsFolder(for: appURL)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url?.standardizedFileURL
    }

    private static func containingApplicationsFolder(for appURL: URL) -> URL {
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true).standardizedFileURL
        if appURL.path.hasPrefix(systemApplications.path + "/") {
            return systemApplications
        }
        return UserHomeDirectory.url
            .appendingPathComponent("Applications", isDirectory: true)
            .standardizedFileURL
    }

    private static func resolveBookmarkedApplicationsFolder(for applicationsFolder: URL) -> URL? {
        let key = applicationsBookmarkKey(for: applicationsFolder)
        guard let bookmark = bookmarkStore.data(forKey: key) else { return nil }

        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ).standardizedFileURL

            guard normalizedPath(for: resolvedURL) == normalizedPath(for: applicationsFolder) else {
                bookmarkStore.removeObject(forKey: key)
                return nil
            }

            if isStale {
                try storeApplicationsFolderBookmark(resolvedURL, for: applicationsFolder)
            }
            return resolvedURL
        } catch {
            bookmarkStore.removeObject(forKey: key)
            return nil
        }
    }

    private static func storeApplicationsFolderBookmark(
        _ url: URL,
        for applicationsFolder: URL
    ) throws {
        let key = applicationsBookmarkKey(for: applicationsFolder)
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        bookmarkStore.set(bookmark, forKey: key)
    }

    private static func applicationsBookmarkKey(for applicationsFolder: URL) -> String {
        "\(applicationsBookmarkKeyPrefix).\(normalizedPath(for: applicationsFolder))"
    }

    private static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

private extension URL {
    func isDescendant(of possibleAncestor: URL) -> Bool {
        let childComponents = standardizedFileURL.pathComponents
        let ancestorComponents = possibleAncestor.standardizedFileURL.pathComponents
        guard childComponents.count > ancestorComponents.count else { return false }
        return zip(childComponents, ancestorComponents).allSatisfy { $0 == $1 }
    }
}
