import Foundation

/// A framework detected within a broader project technology. A project can
/// carry more than one: Next.js also uses React, Nuxt uses Vue, and so on.
enum ProjectFramework: String, CaseIterable, Identifiable, Hashable, Sendable {
    case react = "React"
    case nextJS = "Next.js"
    case vue = "Vue.js"
    case nuxt = "Nuxt"
    case quasar = "Quasar"
    case angular = "Angular"
    case svelte = "Svelte"
    case svelteKit = "SvelteKit"
    case express = "Express"
    case nestJS = "NestJS"
    case laravel = "Laravel"
    case symfony = "Symfony"
    case wordpress = "WordPress"
    case django = "Django"
    case flask = "Flask"
    case fastAPI = "FastAPI"
    case rubyOnRails = "Ruby on Rails"
    case sinatra = "Sinatra"
    case springBoot = "Spring Boot"
    case ktor = "Ktor"
    case aspNetCore = "ASP.NET Core"
    case blazor = "Blazor"
    case vapor = "Vapor"
    case axum = "Axum"
    case actixWeb = "Actix Web"
    case rocket = "Rocket"
    case gin = "Gin"
    case echo = "Echo"
    case fiber = "Fiber"

    var id: String { rawValue }

    static func detected(
        at directory: URL,
        technology: ProjectTechnology,
        fileManager: FileManager = .default
    ) -> Set<ProjectFramework> {
        switch technology {
        case .nodeJS: detectNodeFrameworks(at: directory, fileManager: fileManager)
        case .php: detectPHPFrameworks(at: directory, fileManager: fileManager)
        case .python: detectPythonFrameworks(at: directory, fileManager: fileManager)
        case .ruby: detectRubyFrameworks(at: directory, fileManager: fileManager)
        case .java, .kotlin: detectJVMFrameworks(at: directory, fileManager: fileManager)
        case .dotNet: detectDotNetFrameworks(at: directory, fileManager: fileManager)
        case .swift: detectSwiftFrameworks(at: directory, fileManager: fileManager)
        case .rust: detectRustFrameworks(at: directory, fileManager: fileManager)
        case .golang: detectGoFrameworks(at: directory, fileManager: fileManager)
        default: []
        }
    }

    static func primary(in frameworks: Set<ProjectFramework>) -> ProjectFramework? {
        primaryPriority.first(where: frameworks.contains)
    }

    private static let primaryPriority: [ProjectFramework] = [
        .nextJS, .nuxt, .quasar, .angular, .svelteKit, .nestJS, .react, .vue, .svelte, .express,
        .laravel, .symfony, .wordpress, .django, .fastAPI, .flask, .rubyOnRails, .sinatra,
        .springBoot, .ktor, .blazor, .aspNetCore, .vapor, .axum, .actixWeb, .rocket, .gin, .echo, .fiber
    ]

    private static func detectNodeFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let packages = ProjectDependencyRules.packageJSONDependencies(at: directory, fileManager: fileManager)
        var matches: Set<ProjectFramework> = []
        if packages.contains("react") { matches.insert(.react) }
        if packages.contains("vue") { matches.insert(.vue) }
        if packages.contains("svelte") { matches.insert(.svelte) }
        if packages.contains("next") { matches.formUnion([.nextJS, .react]) }
        if packages.contains("nuxt") { matches.formUnion([.nuxt, .vue]) }
        if !packages.isDisjoint(with: ["quasar", "@quasar/app-vite", "@quasar/app-webpack"]) {
            matches.formUnion([.quasar, .vue])
        }
        if packages.contains("@angular/core") { matches.insert(.angular) }
        if packages.contains("@sveltejs/kit") { matches.formUnion([.svelteKit, .svelte]) }
        if packages.contains("express") { matches.insert(.express) }
        if packages.contains("@nestjs/core") { matches.insert(.nestJS) }
        return matches
    }

    private static func detectPHPFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let packages = ProjectDependencyRules.composerJSONDependencies(at: directory, fileManager: fileManager)
        var matches: Set<ProjectFramework> = []
        if packages.contains("laravel/framework")
            || fileManager.fileExists(atPath: directory.appending(path: "artisan").path) {
            matches.insert(.laravel)
        }
        if packages.contains("symfony/framework-bundle")
            || fileManager.fileExists(atPath: directory.appending(path: "bin/console").path) {
            matches.insert(.symfony)
        }
        if fileManager.fileExists(atPath: directory.appending(path: "wp-config.php").path) {
            matches.insert(.wordpress)
        }
        return matches
    }

    private static func detectPythonFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let manifest = text(
            in: ["pyproject.toml", "requirements.txt", "Pipfile", "setup.py", "setup.cfg", "environment.yml"],
            under: directory,
            fileManager: fileManager
        ).lowercased()
        var matches: Set<ProjectFramework> = []
        if manifest.contains("django") { matches.insert(.django) }
        if manifest.contains("flask") { matches.insert(.flask) }
        if manifest.contains("fastapi") { matches.insert(.fastAPI) }
        return matches
    }

    private static func detectRubyFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        var matches: Set<ProjectFramework> = []
        if ProjectDependencyRules.rubyProjectContainsRails(at: directory, fileManager: fileManager) {
            matches.insert(.rubyOnRails)
        }
        if text(in: ["Gemfile", "Gemfile.lock"], under: directory, fileManager: fileManager).contains("sinatra") {
            matches.insert(.sinatra)
        }
        return matches
    }

    private static func detectJVMFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let manifest = text(
            in: ["pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
            under: directory,
            fileManager: fileManager
        )
        var matches: Set<ProjectFramework> = []
        if manifest.contains("spring-boot") || manifest.contains("org.springframework.boot") {
            matches.insert(.springBoot)
        }
        if manifest.contains("io.ktor") { matches.insert(.ktor) }
        return matches
    }

    private static func detectDotNetFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let projectFiles = ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasSuffix(".csproj") || $0.hasSuffix(".fsproj") || $0.hasSuffix(".vbproj") }
        let manifest = text(in: projectFiles, under: directory, fileManager: fileManager)
        var matches: Set<ProjectFramework> = []
        if manifest.contains("Microsoft.NET.Sdk.Web") || manifest.contains("Microsoft.AspNetCore") {
            matches.insert(.aspNetCore)
        }
        if manifest.localizedCaseInsensitiveContains("blazor")
            || manifest.contains("Microsoft.AspNetCore.Components.WebAssembly") {
            matches.formUnion([.blazor, .aspNetCore])
        }
        return matches
    }

    private static func detectSwiftFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let manifest = text(in: ["Package.swift"], under: directory, fileManager: fileManager)
        return manifest.localizedCaseInsensitiveContains("vapor") ? [.vapor] : []
    }

    private static func detectRustFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let manifest = text(in: ["Cargo.toml"], under: directory, fileManager: fileManager)
        var matches: Set<ProjectFramework> = []
        if manifest.contains("axum") { matches.insert(.axum) }
        if manifest.contains("actix-web") { matches.insert(.actixWeb) }
        if manifest.contains("rocket") { matches.insert(.rocket) }
        return matches
    }

    private static func detectGoFrameworks(at directory: URL, fileManager: FileManager) -> Set<ProjectFramework> {
        let manifest = text(in: ["go.mod"], under: directory, fileManager: fileManager)
        var matches: Set<ProjectFramework> = []
        if manifest.contains("github.com/gin-gonic/gin") { matches.insert(.gin) }
        if manifest.contains("github.com/labstack/echo") { matches.insert(.echo) }
        if manifest.contains("github.com/gofiber/fiber") { matches.insert(.fiber) }
        return matches
    }

    private static func text(in files: [String], under directory: URL, fileManager: FileManager) -> String {
        files.compactMap { name -> String? in
            guard let data = fileManager.contents(atPath: directory.appending(path: name).path) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        .joined(separator: "\n")
    }
}
