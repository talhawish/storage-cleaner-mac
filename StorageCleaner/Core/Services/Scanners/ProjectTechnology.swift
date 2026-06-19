import Foundation

/// A language / framework that `ProjectActivityScanner` can recognise from the
/// files present at a project root. Display metadata (symbol, colour, marker
/// list) is computed on the enum so the UI never deals in magic strings.
enum ProjectTechnology: String, CaseIterable, Identifiable, Hashable, Sendable {
    case flutter = "Flutter"
    case android = "Android"
    case swift = "Swift"
    case dotNet = ".NET"
    case rust = "Rust"
    case golang = "Go"
    case php = "PHP"
    case python = "Python"
    case ruby = "Ruby"
    case nodeJS = "Node.js"
    case kotlin = "Kotlin"
    case java = "Java"

    var id: String { rawValue }

    /// A valid SF Symbol for the technology. Brand glyphs do not exist in SF
    /// Symbols, so distinct lettered symbols are used instead of fake names.
    var symbolName: String {
        switch self {
        case .flutter: "f.square.fill"
        case .android: "a.square.fill"
        case .swift: "swift"
        case .dotNet: "n.circle.fill"
        case .rust: "r.square.fill"
        case .golang: "g.square.fill"
        case .php: "p.circle.fill"
        case .python: "p.square.fill"
        case .ruby: "diamond.fill"
        case .nodeJS: "n.square.fill"
        case .kotlin: "k.square.fill"
        case .java: "j.square.fill"
        }
    }

    /// Brand colour as an RGB hex string (consumed by `Color(hex:)`).
    var color: String {
        switch self {
        case .flutter: "02569B"
        case .android: "3DDC84"
        case .swift: "F05138"
        case .dotNet: "512BD4"
        case .rust: "CE412B"
        case .golang: "00ADD8"
        case .php: "777BB4"
        case .python: "3776AB"
        case .ruby: "CC342D"
        case .nodeJS: "68A063"
        case .kotlin: "7F52FF"
        case .java: "ED8B00"
        }
    }

    /// Human-readable marker files, derived from the detection rules so the two
    /// never drift apart.
    var markerFiles: [String] {
        ProjectDetector.markers(for: self).map(\.displayName)
    }

    /// Directories that hold downloaded/generated dependencies rather than
    /// hand-written source. Their size is reported separately and excluded from
    /// activity (a dependency install should not make a project look "active").
    var dependencyDirectoryNames: Set<String> {
        switch self {
        case .flutter: [".dart_tool", "build", ".pub-cache"]
        case .android: ["build", ".gradle", ".cxx"]
        case .swift: [".build", "DerivedData", "Pods", ".swiftpm"]
        case .dotNet: ["bin", "obj", "packages"]
        case .rust: ["target"]
        case .golang: ["vendor"]
        case .php: ["vendor"]
        case .python: ["venv", ".venv", "env", "__pycache__", ".tox", "dist", "build", ".eggs"]
        case .ruby: ["vendor", ".bundle"]
        case .nodeJS: ["node_modules", ".next", ".nuxt", ".turbo", "dist", "build", ".cache"]
        case .kotlin: ["build", ".gradle"]
        case .java: ["build", ".gradle", "target"]
        }
    }
}

/// A single signal that a directory belongs to a technology.
enum ProjectMarker: Hashable, Sendable {
    /// An exact file name present in the directory (e.g. `Package.swift`).
    case file(String)
    /// Any entry with this extension is present (e.g. `csproj` matches `App.csproj`).
    case fileExtension(String)
    /// A nested path that exists relative to the directory (e.g. `app/build.gradle`).
    case relativePath(String)
    /// A Composer PHP project, identified by `composer.json` or `vendor/autoload.php`.
    case composerProject

    var displayName: String {
        switch self {
        case let .file(name): name
        case let .fileExtension(ext): "*.\(ext)"
        case let .relativePath(path): path
        case .composerProject: "composer.json or vendor/autoload.php"
        }
    }

    func matches(in directory: URL, contents: Set<String>, fileManager: FileManager) -> Bool {
        switch self {
        case let .file(name):
            contents.contains(name)
        case let .fileExtension(ext):
            contents.contains { $0.hasSuffix(".\(ext)") }
        case let .relativePath(path):
            fileManager.fileExists(atPath: directory.appendingPathComponent(path).path)
        case .composerProject:
            ProjectDependencyRules.isComposerProject(at: directory, fileManager: fileManager)
        }
    }
}

/// A technology paired with the markers that identify it. The first rule whose
/// markers match wins, so rules are ordered most-specific first.
struct ProjectDetectionRule: Sendable {
    let technology: ProjectTechnology
    let markers: [ProjectMarker]
}

/// Pure, testable project detection. Decoupled from the filesystem-walking
/// scanner so it can be exercised against fixtures without a full scan.
enum ProjectDetector {
    /// Priority-ordered detection rules. Framework-specific markers (Flutter,
    /// Android) precede the generic build tools they are layered on top of
    /// (Gradle → Kotlin/Java), so an Android project is never misread as plain
    /// Java and a Flutter project is never misread as Android.
    static let rules: [ProjectDetectionRule] = [
        ProjectDetectionRule(technology: .flutter, markers: [
            .file("pubspec.yaml")
        ]),
        ProjectDetectionRule(technology: .android, markers: [
            .relativePath("app/src/main/AndroidManifest.xml"),
            .relativePath("src/main/AndroidManifest.xml"),
            .file("AndroidManifest.xml"),
            .relativePath("app/build.gradle"),
            .relativePath("app/build.gradle.kts")
        ]),
        ProjectDetectionRule(technology: .swift, markers: [
            .file("Package.swift"),
            .fileExtension("xcodeproj"),
            .fileExtension("xcworkspace")
        ]),
        ProjectDetectionRule(technology: .dotNet, markers: [
            .fileExtension("sln"),
            .fileExtension("csproj"),
            .fileExtension("fsproj"),
            .fileExtension("vbproj"),
            .file("global.json")
        ]),
        ProjectDetectionRule(technology: .rust, markers: [
            .file("Cargo.toml")
        ]),
        ProjectDetectionRule(technology: .golang, markers: [
            .file("go.mod")
        ]),
        ProjectDetectionRule(technology: .php, markers: [
            .composerProject
        ]),
        ProjectDetectionRule(technology: .python, markers: [
            .file("pyproject.toml"),
            .file("requirements.txt"),
            .file("setup.py"),
            .file("setup.cfg"),
            .file("Pipfile"),
            .file("environment.yml")
        ]),
        ProjectDetectionRule(technology: .ruby, markers: [
            .file("Gemfile"),
            .fileExtension("gemspec")
        ]),
        ProjectDetectionRule(technology: .nodeJS, markers: [
            .file("package.json")
        ]),
        ProjectDetectionRule(technology: .kotlin, markers: [
            .file("build.gradle.kts"),
            .file("settings.gradle.kts")
        ]),
        ProjectDetectionRule(technology: .java, markers: [
            .file("pom.xml"),
            .file("build.gradle"),
            .file("settings.gradle"),
            .file("build.xml")
        ])
    ]

    /// The markers used to detect a given technology.
    static func markers(for technology: ProjectTechnology) -> [ProjectMarker] {
        rules.first { $0.technology == technology }?.markers ?? []
    }

    /// Detect the technology of the project rooted at `directory`, or `nil` if
    /// the directory contains no recognised project markers.
    static func detect(at directory: URL, fileManager: FileManager = .default) -> ProjectTechnology? {
        let entries = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        guard !entries.isEmpty else { return nil }
        let contents = Set(entries)

        return rules.first { rule in
            rule.markers.contains { $0.matches(in: directory, contents: contents, fileManager: fileManager) }
        }?.technology
    }
}
