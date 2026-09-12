import Foundation

enum ProjectDependencyRules {
    /// `true` when a package is declared in a package.json dependency section.
    /// Parsing keys avoids false positives from project names, scripts, and descriptions.
    static func packageJSONContains(
        _ dependency: String,
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        packageJSONDependencies(at: directory, fileManager: fileManager).contains(dependency)
    }

    static func packageJSONDependencies(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Set<String> {
        guard let data = fileManager.contents(atPath: directory.appending(path: "package.json").path),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        return ["dependencies", "devDependencies", "peerDependencies", "optionalDependencies"]
            .reduce(into: Set<String>()) { packages, section in
                guard let dependencies = object[section] as? [String: Any] else { return }
                packages.formUnion(dependencies.keys)
            }
    }

    static func isComposerProject(at directory: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: directory.appending(path: "composer.json").path)
            || isComposerVendorDirectory(directory.appending(path: "vendor", directoryHint: .isDirectory))
    }

    static func composerJSONDependencies(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Set<String> {
        guard let data = fileManager.contents(atPath: directory.appending(path: "composer.json").path),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        return ["require", "require-dev"].reduce(into: Set<String>()) { packages, section in
            guard let dependencies = object[section] as? [String: Any] else { return }
            packages.formUnion(dependencies.keys)
        }
    }

    static func rubyProjectContainsRails(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        ["Gemfile", "Gemfile.lock"].contains { name in
            guard let data = fileManager.contents(atPath: directory.appending(path: name).path),
                  let text = String(data: data, encoding: .utf8) else {
                return false
            }
            return text.range(
                of: #"(?m)^\s*gem\s+['\"]rails['\"]"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil || text.range(
                of: #"(?m)^\s{4}rails\s+\("#,
                options: .regularExpression
            ) != nil
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

        if technology == .ruby {
            let components = relativePathComponents(of: directory, under: projectRoot)
            return components == [".bundle"]
                || components.suffix(2).elementsEqual(["vendor", "bundle"])
        }

        return technology.dependencyDirectoryNames.contains(directory.lastPathComponent)
    }

    static func isDependencyDirectory(
        _ directory: URL,
        for technologies: Set<ProjectTechnology>,
        projectRoot: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        technologies.contains { technology in
            isDependencyDirectory(
                directory,
                for: technology,
                projectRoot: projectRoot,
                fileManager: fileManager
            )
        }
    }

    private static func relativePathComponents(of url: URL, under root: URL) -> [String] {
        let rootComponents = root.standardizedFileURL.pathComponents
        let components = url.standardizedFileURL.pathComponents
        guard components.starts(with: rootComponents) else { return [] }
        return Array(components.dropFirst(rootComponents.count))
    }

}
