import Foundation

enum ProjectTechnology: String, CaseIterable, Identifiable, Hashable, Sendable {
    case nodeJS = "Node.js"
    case swift = "Swift"
    case kotlin = "Kotlin"
    case python = "Python"
    case rust = "Rust"
    case go = "Go"
    case php = "PHP"
    case ruby = "Ruby"
    case dotNet = ".NET"
    case flutter = "Flutter"
    case java = "Java"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .nodeJS: return "nodejs"
        case .swift: return "swift"
        case .kotlin: return "kotlin"
        case .python: return "python"
        case .rust: return "rust"
        case .go: return "golang"
        case .php: return "php"
        case .ruby: return "ruby"
        case .dotNet: return "dotnet"
        case .flutter: return "flutter"
        case .java: return "cup.and.saucer"
        }
    }

    var color: String {
        switch self {
        case .nodeJS: return "68A063"
        case .swift: return "F05138"
        case .kotlin: return "7F52FF"
        case .python: return "3776AB"
        case .rust: return "CE412B"
        case .go: return "00ADD8"
        case .php: return "777BB4"
        case .ruby: return "CC342D"
        case .dotNet: return "512BD4"
        case .flutter: return "02569B"
        case .java: return "ED8B00"
        }
    }

    var markerFiles: [String] {
        switch self {
        case .nodeJS: return ["package.json"]
        case .swift: return ["Package.swift", "*.xcodeproj", "*.xcworkspace"]
        case .kotlin: return ["build.gradle.kts", "build.gradle"]
        case .python: return ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"]
        case .rust: return ["Cargo.toml"]
        case .go: return ["go.mod"]
        case .php: return ["composer.json"]
        case .ruby: return ["Gemfile"]
        case .dotNet: return ["*.csproj", "*.sln"]
        case .flutter: return ["pubspec.yaml"]
        case .java: return ["pom.xml"]
        }
    }
}

enum ProjectActivityStatus: String, CaseIterable, Identifiable, Hashable, Sendable {
    case active
    case dormant
    case inactive
    case abandoned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: return "Active"
        case .dormant: return "Dormant"
        case .inactive: return "Inactive"
        case .abandoned: return "Abandoned"
        }
    }

    var description: String {
        switch self {
        case .active: return "Worked on within the last 30 days"
        case .dormant: return "No changes in 1–3 months"
        case .inactive: return "No changes in 3–12 months"
        case .abandoned: return "No changes in over a year"
        }
    }

    var color: String {
        switch self {
        case .active: return "34C759"
        case .dormant: return "FF9F0A"
        case .inactive: return "FF453A"
        case .abandoned: return "8E8E93"
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .dormant: return "moon.fill"
        case .inactive: return "clock.fill"
        case .abandoned: return "exclamationmark.triangle.fill"
        }
    }
}

struct ProjectInfo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let path: URL
    let technology: ProjectTechnology
    let lastModifiedDate: Date
    let totalSize: Int64
    let childProjectCount: Int
    let dependencySize: Int64

    var activityStatus: ProjectActivityStatus {
        let daysSinceLastModified = Calendar.current.dateComponents([.day], from: lastModifiedDate, to: .now).day ?? 0
        switch daysSinceLastModified {
        case 0..<30: return .active
        case 30..<90: return .dormant
        case 90..<365: return .inactive
        default: return .abandoned
        }
    }

    var lastModifiedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastModifiedDate, relativeTo: .now)
    }

    var projectSize: Int64 {
        totalSize - dependencySize
    }
}

struct ProjectActivitySnapshot: Sendable {
    let projects: [ProjectInfo]
    let scannedAt: Date
    let scanDuration: TimeInterval

    var totalSize: Int64 {
        projects.reduce(0) { $0 + $1.totalSize }
    }

    var projectsByTechnology: [ProjectTechnology: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.technology }
    }

    var projectsByActivity: [ProjectActivityStatus: [ProjectInfo]] {
        Dictionary(grouping: projects) { $0.activityStatus }
    }

    var inactiveProjects: [ProjectInfo] {
        projects.filter { $0.activityStatus == .inactive || $0.activityStatus == .abandoned }
    }

    var hibernatableSize: Int64 {
        inactiveProjects.reduce(0) { $0 + $1.totalSize }
    }
}

actor ProjectActivityScanner {
    private let fileManager = FileManager.default
    private let maxSize: Int64 = 500_000_000

    func scan() async -> ProjectActivitySnapshot {
        let startTime = Date()
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser

        let searchPaths: [URL] = [
            homeDirectory.appendingPathComponent("Developer"),
            homeDirectory.appendingPathComponent("Documents"),
            homeDirectory.appendingPathComponent("Desktop"),
            homeDirectory.appendingPathComponent("Projects"),
            homeDirectory.appendingPathComponent("Code"),
            homeDirectory.appendingPathComponent("Work"),
            homeDirectory.appendingPathComponent("dev"),
            homeDirectory.appendingPathComponent("src"),
        ]

        var projects: [ProjectInfo] = []
        let seenPaths = Set<String>()

        for searchPath in searchPaths {
            guard fileManager.fileExists(atPath: searchPath.path) else { continue }

            let foundProjects = await scanDirectory(searchPath, depth: 0, seenPaths: &projects)
            for project in foundProjects {
                let key = project.path.path
                if !seenPaths.contains(key) {
                    projects.append(project)
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return ProjectActivitySnapshot(
            projects: projects.sorted { $0.totalSize > $1.totalSize },
            scannedAt: .now,
            scanDuration: duration
        )
    }

    private func scanDirectory(_ directory: URL, depth: Int, seenPaths: inout [ProjectInfo]) async -> [ProjectInfo] {
        guard depth < 3 else { return [] }

        var projects: [ProjectInfo] = []
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

        while let item = enumerator?.nextObject() as? URL {
            guard let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory,
                  isDirectory else { continue }

            if let detected = detectProject(at: item) {
                projects.append(detected)
                enumerator?.skipDescendants()
            }
        }

        return projects
    }

    private func detectProject(at directory: URL) -> ProjectInfo? {
        for technology in ProjectTechnology.allCases {
            for marker in technology.markerFiles {
                if marker.contains("*") {
                    let pattern = marker.replacingOccurrences(of: "*", with: "")
                    let contents = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
                    if contents.contains(where: { $0.hasSuffix(pattern) }) {
                        return buildProjectInfo(at: directory, technology: technology)
                    }
                } else {
                    let markerPath = directory.appendingPathComponent(marker).path
                    if fileManager.fileExists(atPath: markerPath) {
                        return buildProjectInfo(at: directory, technology: technology)
                    }
                }
            }
        }
        return nil
    }

    private func buildProjectInfo(at directory: URL, technology: ProjectTechnology) -> ProjectInfo? {
        let name = directory.lastPathComponent
        let modDate = (try? fileManager.attributesOfItem(atPath: directory.path)[.modificationDate] as? Date) ?? .distantPast
        let size = calculateSize(at: directory)
        let depSize = calculateDependencySize(at: directory, technology: technology)
        let childCount = countSubProjects(at: directory, technology: technology)

        guard size > 0 else { return nil }

        return ProjectInfo(
            name: name,
            path: directory,
            technology: technology,
            lastModifiedDate: modDate,
            totalSize: size,
            childProjectCount: childCount,
            dependencySize: depSize
        )
    }

    private func calculateSize(at directory: URL) -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            if let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    private func calculateDependencySize(at directory: URL, technology: ProjectTechnology) -> Int64 {
        let depDirNames: [String]
        switch technology {
        case .nodeJS: depDirNames = ["node_modules", ".next", "dist", "build"]
        case .swift: depDirNames = [".build", "DerivedData", "Pods"]
        case .kotlin, .java: depDirNames = ["build", ".gradle", "Pods"]
        case .python: depDirNames = ["venv", ".venv", "__pycache__", "dist", "build"]
        case .rust: depDirNames = ["target"]
        case .go: depDirNames = []
        case .php: depDirNames = ["vendor"]
        case .ruby: depDirNames = ["vendor", ".bundle"]
        case .dotNet: depDirNames = ["bin", "obj", "packages"]
        case .flutter: depDirNames = [".dart_tool", "build"]
        }

        var depSize: Int64 = 0
        for depDir in depDirNames {
            let depPath = directory.appendingPathComponent(depDir)
            if fileManager.fileExists(atPath: depPath.path) {
                depSize += calculateSize(at: depPath)
            }
        }
        return depSize
    }

    private func countSubProjects(at directory: URL, technology: ProjectTechnology) -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return 0 }
        return contents.filter { $0.hasPrefix(".") == false }.count
    }
}
