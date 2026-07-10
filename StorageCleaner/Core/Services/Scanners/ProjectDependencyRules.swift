import Foundation

enum ProjectDependencyRules {
    /// `true` if `directory/package.json` exists and its contents contain `dependency` as a
    /// substring. Reading the whole file keeps the marker simple; detection runs once per
    /// project root so the cost is bounded. Linear scan is intentional — avoiding a JSON
    /// dependency keeps this file Foundation-only.
    static func packageJSONContains(
        _ dependency: String,
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let packageJSON = directory.appending(path: "package.json")
        guard fileManager.fileExists(atPath: packageJSON.path),
              let data = fileManager.contents(atPath: packageJSON.path),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }
        return text.contains(dependency)
    }

    static func isComposerProject(at directory: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: directory.appending(path: "composer.json").path)
            || isComposerVendorDirectory(directory.appending(path: "vendor", directoryHint: .isDirectory))
    }

    static func composerJSONContains(
        _ needle: String,
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        textFileContains(needle, at: directory.appending(path: "composer.json"), fileManager: fileManager)
    }

    static func pythonProjectContains(
        _ needle: String,
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        [
            "pyproject.toml",
            "requirements.txt",
            "Pipfile",
            "setup.py",
            "setup.cfg",
            "environment.yml"
        ].contains { name in
            textFileContains(needle, at: directory.appending(path: name), fileManager: fileManager)
        }
    }

    static func isComposerVendorDirectory(_ directory: URL, fileManager: FileManager = .default) -> Bool {
        guard directory.lastPathComponent == "vendor" else { return false }

        let projectRoot = directory.deletingLastPathComponent()
        return fileManager.fileExists(atPath: projectRoot.appending(path: "composer.json").path)
            || fileManager.fileExists(atPath: directory.appending(path: "autoload.php").path)
    }

    static func isDependencyDirectory(
        _ directory: URL,
        for technology: ProjectTechnology,
        projectRoot: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        if technology == .php {
            return isComposerVendorDirectory(directory, fileManager: fileManager)
        }

        return technology.dependencyDirectoryNames.contains(directory.lastPathComponent)
    }

    static func isDependencyFile(
        _ file: URL,
        for technology: ProjectTechnology,
        projectRoot: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let rootComponents = projectRoot.standardizedFileURL.pathComponents
        let fileComponents = file.standardizedFileURL.pathComponents
        guard fileComponents.starts(with: rootComponents) else { return false }

        let relativeComponents = Array(fileComponents.dropFirst(rootComponents.count))
        if technology == .php {
            return relativeComponents.indices.contains { index in
                guard relativeComponents[index] == "vendor" else { return false }
                let vendorURL = URL(
                    fileURLWithPath: NSString.path(
                        withComponents: rootComponents + Array(relativeComponents.prefix(index + 1))
                    ),
                    isDirectory: true
                )
                return isComposerVendorDirectory(vendorURL, fileManager: fileManager)
            }
        }

        return relativeComponents.contains(where: technology.dependencyDirectoryNames.contains)
    }

    private static func textFileContains(
        _ needle: String,
        at url: URL,
        fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: url.path),
              let data = fileManager.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }
        return text.range(of: needle, options: [.caseInsensitive]) != nil
    }
}
