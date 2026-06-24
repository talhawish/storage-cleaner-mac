import Foundation

enum AppBundleUninstallerError: LocalizedError, Sendable {
    case unsupportedLocation(URL)
    case administratorApprovalFailed(URL, String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedLocation(url):
            "Refusing to uninstall \(url.path) because it is not an application bundle in an Applications folder."
        case let .administratorApprovalFailed(url, message):
            "Administrator approval did not uninstall \(url.lastPathComponent): \(message)"
        }
    }
}

struct AppBundleUninstaller: Sendable {
    struct CommandOutput: Sendable {
        let exitCode: Int32
        let output: String

        var succeeded: Bool { exitCode == 0 }
    }

    var removeDirectly: @Sendable (URL) throws -> Void
    var runAdministratorScript: @Sendable (String) async -> CommandOutput

    func uninstall(_ url: URL) async throws {
        let appURL = url.standardizedFileURL
        guard Self.supportsAdministratorRemoval(for: appURL) else {
            throw AppBundleUninstallerError.unsupportedLocation(appURL)
        }

        do {
            try await Task.detached(priority: .userInitiated) {
                try removeDirectly(appURL)
            }.value
        } catch {
            guard Self.isPermissionError(error) else { throw error }
            try await uninstallWithAdministratorApproval(appURL)
        }
    }

    private func uninstallWithAdministratorApproval(_ appURL: URL) async throws {
        let script = Self.administratorRemovalScript(for: appURL)
        let output = await runAdministratorScript(script)
        guard output.succeeded else {
            throw AppBundleUninstallerError.administratorApprovalFailed(
                appURL,
                Self.firstMeaningfulLine(of: output.output)
            )
        }
    }
}

extension AppBundleUninstaller {
    static let live = AppBundleUninstaller(
        removeDirectly: { url in
            try FileManager.default.removeItem(at: url)
        },
        runAdministratorScript: { script in
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
    )

    static func supportsAdministratorRemoval(for url: URL) -> Bool {
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

    static func administratorRemovalScript(for url: URL) -> String {
        let escapedPath = escapedAppleScriptString(url.standardizedFileURL.path)
        return #"do shell script "/bin/rm -rf -- " & quoted form of "\#(escapedPath)" with administrator privileges"#
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return false }

        let code = CocoaError.Code(rawValue: nsError.code)
        return code == .fileWriteNoPermission || code == .fileReadNoPermission
    }

    static func firstMeaningfulLine(of output: String) -> String {
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
}
