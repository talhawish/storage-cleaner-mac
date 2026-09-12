import Foundation

/// Finds project boundaries nested inside a repository without emitting them
/// as separate top-level projects. The bounded breadth-first walk avoids
/// dependency trees and stops at ordinary child project roots, keeping
/// monorepo discovery fast and preventing storage double-counting.
enum ProjectComponentDiscovery {
    private static let maximumDepth = 4
    private static let excludedDirectoryNames: Set<String> = [
        ".git", ".hg", ".svn", ".idea", ".vscode", ".firebase",
        "node_modules", "Pods", "DerivedData", ".dart_tool", ".pub-cache",
        ".gradle", ".cxx", ".build", ".swiftpm", ".nuxt", ".next",
        ".output", ".turbo", ".quasar", ".cache", "target", "vendor",
        "dist", "build", "bin", "obj"
    ]

    private struct Candidate {
        let url: URL
        let depth: Int
    }

    static func discover(
        in projectRoot: URL,
        rootTechnology: ProjectTechnology,
        fileManager: FileManager = .default
    ) -> [ProjectComponentInfo] {
        var queue = childDirectories(
            of: projectRoot,
            rootTechnology: rootTechnology,
            depth: 1,
            fileManager: fileManager
        )
        var index = 0
        var components: [ProjectComponentInfo] = []

        while index < queue.count {
            guard !Task.isCancelled else { break }
            let candidate = queue[index]
            index += 1

            let technologies = ProjectDetector.detectAll(at: candidate.url, fileManager: fileManager)
            if let technology = ProjectDetector.primaryTechnology(in: technologies) {
                let frameworks = technologies.reduce(into: Set<ProjectFramework>()) { result, stack in
                    result.formUnion(ProjectFramework.detected(
                        at: candidate.url,
                        technology: stack,
                        fileManager: fileManager
                    ))
                }
                components.append(ProjectComponentInfo(
                    name: candidate.url.lastPathComponent,
                    path: candidate.url,
                    technology: technology,
                    technologies: technologies,
                    frameworks: frameworks
                ))
                continue
            }

            guard candidate.depth < maximumDepth else { continue }
            queue.append(contentsOf: childDirectories(
                of: candidate.url,
                rootTechnology: rootTechnology,
                depth: candidate.depth + 1,
                fileManager: fileManager
            ))
        }

        return components.sorted { $0.path.path < $1.path.path }
    }

    private static func childDirectories(
        of directory: URL,
        rootTechnology: ProjectTechnology,
        depth: Int,
        fileManager: FileManager
    ) -> [Candidate] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { url in
            guard !shouldSkip(url, rootTechnology: rootTechnology),
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                return nil
            }
            return Candidate(url: url, depth: depth)
        }
    }

    private static func shouldSkip(_ directory: URL, rootTechnology: ProjectTechnology) -> Bool {
        let name = directory.lastPathComponent
        guard !name.hasPrefix("."), !excludedDirectoryNames.contains(name) else { return true }

        switch rootTechnology {
        case .flutter:
            return ["android", "ios", "linux", "macos", "web", "windows"].contains(name)
        case .reactNative:
            return ["android", "ios"].contains(name)
        case .dotNet:
            return name == "packages"
        default:
            return false
        }
    }
}
