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
            try await trashWithFileManager(url)
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

    private static func trashWithFileManager(_ url: URL) async throws {
        do {
            var resultingItemURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingItemURL)
        } catch {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                NSWorkspace.shared.recycle([url]) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    @MainActor
    private static func trashWithUserSelectedApplicationsAccess(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        let applicationsFolder = containingApplicationsFolder(for: appURL)

        if let bookmarkedAccessURL = resolveBookmarkedApplicationsFolder(for: applicationsFolder),
           appURL.isDescendant(of: bookmarkedAccessURL) {
            do {
                try await trash(appURL, withAccessTo: bookmarkedAccessURL)
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
            try await trash(appURL, withAccessTo: accessURL)
        } catch {
            guard Self.isPermissionError(error) else { throw error }
            throw error
        }
    }

    private static func trashWithAdministratorAuthorization(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        let output = await runAppleScript(administratorTrashScript(for: appURL))
        guard output.succeeded else {
            throw AppBundleUninstallerError.administratorApprovalFailed(
                appURL,
                firstMeaningfulLine(of: output.output)
            )
        }
    }

    private static func administratorTrashScript(for url: URL) -> String {
        let sourcePath = escapedAppleScriptString(url.standardizedFileURL.path)
        let trashPath = escapedAppleScriptString(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".Trash", isDirectory: true)
                .path
        )
        let fileName = escapedAppleScriptString(url.lastPathComponent)
        return """
        set sourcePath to "\(sourcePath)"
        set trashPath to "\(trashPath)"
        set fileName to "\(fileName)"
        set destinationPath to trashPath & "/" & fileName
        set testCommand to "/bin/test -e " & quoted form of destinationPath
        set destinationExists to do shell script testCommand & " && /bin/echo yes || /bin/echo no"
        if destinationExists is "yes" then
            set destinationPath to destinationPath & "." & (do shell script "/bin/date +%Y%m%d%H%M%S")
        end if
        set trashCommand to "/bin/mkdir -p " & quoted form of trashPath
        set moveCommand to "/bin/mv -- " & quoted form of sourcePath & " " & quoted form of destinationPath
        do shell script trashCommand & " && " & moveCommand with administrator privileges
        """
    }

    private static func runAppleScript(_ script: String) async -> CommandOutput {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                return CommandOutput(exitCode: -1, output: error.localizedDescription)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandOutput(
                exitCode: process.terminationStatus,
                output: String(bytes: data, encoding: .utf8) ?? ""
            )
        }.value
    }

    private static func firstMeaningfulLine(of output: String) -> String {
        let line = output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line ?? "The administrator request was cancelled or failed."
    }

    private static func escapedAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func trash(_ appURL: URL, withAccessTo accessURL: URL) async throws {
        let didStartAccess = accessURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                accessURL.stopAccessingSecurityScopedResource()
            }
        }

        guard appURL.isDescendant(of: accessURL) || appURL == accessURL else {
            throw AppBundleUninstallerError.selectedLocationDoesNotAuthorizeTrash(appURL)
        }

        try await trashWithFileManager(appURL)
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

private struct CommandOutput: Sendable {
    let exitCode: Int32
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

private extension URL {
    func isDescendant(of possibleAncestor: URL) -> Bool {
        let childComponents = standardizedFileURL.pathComponents
        let ancestorComponents = possibleAncestor.standardizedFileURL.pathComponents
        guard childComponents.count > ancestorComponents.count else { return false }
        return zip(childComponents, ancestorComponents).allSatisfy { $0 == $1 }
    }
}
