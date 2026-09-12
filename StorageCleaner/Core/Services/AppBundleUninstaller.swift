import AppKit
import Foundation

enum AppBundleUninstallerError: LocalizedError, Sendable {
    case unsupportedLocation(URL)
    case applicationsAccessNotGranted(URL)
    case selectedLocationDoesNotAuthorizeTrash(URL)
    case authorizationRequired(URL)
    case administratorApprovalFailed(URL, String)

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
        case let .administratorApprovalFailed(url, message):
            "Administrator approval did not move \(url.lastPathComponent) to Trash: \(message)"
        }
    }
}

struct AppBundleUninstaller: Sendable {
    var moveToTrashDirectly: @Sendable (URL) async throws -> Void
    var moveToTrashWithUserSelectedAccess: @Sendable (URL) async throws -> Void
    var moveToTrashWithAdminAuthorization: @Sendable (URL) async throws -> Void

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
                try await moveToTrashWithAdminAuthorization(appURL)
            }
        }
    }
}

extension AppBundleUninstaller {
    private static let applicationsBookmarkKeyPrefix = "ApplicationsFolderSecurityScopedBookmark"
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
        moveToTrashWithAdminAuthorization: { url in
            try await trashWithAdministratorAuthorization(url)
        }
    )

    static func supportsAppTrashRemoval(for url: URL) -> Bool {
        let appURL = url.standardizedFileURL
        guard appURL.pathExtension == "app" else { return false }

        let allowedRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            UserHomeDirectory.url.appendingPathComponent(
                "Applications",
                isDirectory: true
            )
        ]

        return allowedRoots
            .map { $0.standardizedFileURL.path + "/" }
            .contains { appURL.path.hasPrefix($0) }
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

    /// Lets Finder perform the privileged delete operation. A sandboxed app cannot
    /// elevate itself with Authorization Services; Finder owns the administrator/
    /// Touch ID prompt and keeps the bundle recoverable in Trash.
    @MainActor
    private static func trashWithAdministratorAuthorization(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        NSApp.activate(ignoringOtherApps: true)

        guard let script = NSAppleScript(source: finderTrashScript(for: appURL)) else {
            throw AppBundleUninstallerError.administratorApprovalFailed(
                appURL,
                "Finder could not prepare the administrator authorization request."
            )
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = meaningfulMessage(from: errorInfo)
            if isFinderAuthorizationDenial(errorInfo) {
                throw AppBundleUninstallerError.authorizationRequired(appURL)
            }
            throw AppBundleUninstallerError.administratorApprovalFailed(appURL, message)
        }
    }

    static func finderTrashScript(for url: URL) -> String {
        let path = escapedAppleScriptString(url.standardizedFileURL.path)
        return """
        set targetPath to "\(path)"
        tell application id "com.apple.finder"
            delete POSIX file targetPath
        end tell
        """
    }

    private static func meaningfulMessage(from errorInfo: NSDictionary?) -> String {
        let message = errorInfo?[NSAppleScript.errorMessage] as? String
        return if let message, !message.isEmpty {
            message
        } else {
            "The administrator request was cancelled or failed."
        }
    }

    private static func isFinderAuthorizationDenial(_ errorInfo: NSDictionary?) -> Bool {
        guard let errorNumber = errorInfo?[NSAppleScript.errorNumber] as? NSNumber else {
            return false
        }
        // -1743 is the TCC denial returned when macOS has not allowed Apple Events;
        // -60005 is the SecurityAgent authorization denial. Treat either as an
        // authorization failure so the UI does not expose a raw script error.
        return errorNumber.intValue == -1743 || errorNumber.intValue == -60005
    }

    private static func escapedAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
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
