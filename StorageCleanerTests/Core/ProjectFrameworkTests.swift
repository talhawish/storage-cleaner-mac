import Foundation
import XCTest
@testable import StorageCleaner

final class ProjectFrameworkTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testDetectsAdditionalFrameworkBreakdownWithoutChangingTechnology() async throws {
        let quasar = try makeProject(named: "quasar_app", marker: "package.json")
        try #"{"devDependencies":{"quasar":"^2.18.0"}}"#.write(
            to: quasar.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )
        let symfony = try makeProject(named: "symfony_app", marker: "composer.json")
        try #"{"require":{"symfony/framework-bundle":"^7.0"}}"#.write(
            to: symfony.appending(path: "composer.json"),
            atomically: true,
            encoding: .utf8
        )
        let rails = try makeProject(named: "rails_app", marker: "Gemfile")
        try #"gem "rails", "~> 8.0""#.write(
            to: rails.appending(path: "Gemfile"),
            atomically: true,
            encoding: .utf8
        )

        let scanner = ProjectActivityScanner(searchPaths: [temporaryDirectory], maxDepth: 2, minimumProjectSize: 1)
        let snapshot = await scanner.scan()

        XCTAssertEqual(snapshot.projects.first { $0.name == "quasar_app" }?.technology, .nodeJS)
        XCTAssertEqual(snapshot.projects.first { $0.name == "quasar_app" }?.frameworks, [.quasar, .vue])
        XCTAssertEqual(snapshot.projects.first { $0.name == "symfony_app" }?.frameworks, [.symfony])
        XCTAssertEqual(snapshot.projects.first { $0.name == "rails_app" }?.frameworks, [.rubyOnRails])
        XCTAssertEqual(snapshot.frameworkBreakdown.count, 4)
    }

    func testPackageJSONFrameworkDetectionDoesNotMatchUnrelatedText() throws {
        let root = try makeProject(named: "next_release_notes", marker: "package.json")
        try #"{"name":"next-release-notes","dependencies":{"react":"18.2.0"}}"#.write(
            to: root.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        let frameworks = ProjectFramework.detected(at: root, technology: .nodeJS)
        XCTAssertEqual(frameworks, [.react])
        XCTAssertFalse(frameworks.contains(.nextJS), "project metadata must not be mistaken for a Next.js dependency")
    }

    func testNodeFrameworksIncludeUnderlyingLayers() throws {
        let root = try makeProject(named: "web", marker: "package.json")
        try #"{"dependencies":{"next":"15","vue":"3","@angular/core":"20","@sveltejs/kit":"2"}}"#.write(
            to: root.appending(path: "package.json"),
            atomically: true,
            encoding: .utf8
        )

        let frameworks = ProjectFramework.detected(at: root, technology: .nodeJS)

        XCTAssertTrue(frameworks.isSuperset(of: [.nextJS, .react, .vue, .angular, .svelteKit, .svelte]))
    }

    func testDetectsSpringBootAndKtorFromGradleManifest() throws {
        let root = try makeProject(named: "jvm", marker: "build.gradle.kts")
        try "plugins { id(\"org.springframework.boot\") }; implementation(\"io.ktor:ktor-server-core\")".write(
            to: root.appending(path: "build.gradle.kts"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectFramework.detected(at: root, technology: .kotlin), [.springBoot, .ktor])
    }

    func testDetectsASPNETCoreAndBlazorFromProjectManifest() throws {
        let root = try makeProject(named: "dotnet", marker: "Web.csproj")
        let manifest = #"<Project Sdk="Microsoft.NET.Sdk.Web">"#
            + #"<PackageReference Include="Microsoft.AspNetCore.Components.WebAssembly" /></Project>"#
        try manifest.write(
            to: root.appending(path: "Web.csproj"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectFramework.detected(at: root, technology: .dotNet), [.aspNetCore, .blazor])
    }

    func testDetectsPopularPythonRustAndGoFrameworks() throws {
        let python = try makeProject(named: "python", marker: "requirements.txt")
        try "Flask==3\nfastapi==0.115".write(
            to: python.appending(path: "requirements.txt"),
            atomically: true,
            encoding: .utf8
        )
        let rust = try makeProject(named: "rust", marker: "Cargo.toml")
        try "[dependencies]\naxum = \"0.8\"\nactix-web = \"4\"".write(
            to: rust.appending(path: "Cargo.toml"),
            atomically: true,
            encoding: .utf8
        )
        let golang = try makeProject(named: "go", marker: "go.mod")
        try "require github.com/gin-gonic/gin v1.10.0".write(
            to: golang.appending(path: "go.mod"),
            atomically: true,
            encoding: .utf8
        )

        XCTAssertEqual(ProjectFramework.detected(at: python, technology: .python), [.flask, .fastAPI])
        XCTAssertEqual(ProjectFramework.detected(at: rust, technology: .rust), [.axum, .actixWeb])
        XCTAssertEqual(ProjectFramework.detected(at: golang, technology: .golang), [.gin])
    }

    func testEveryFrameworkHasAReusableVisualIdentity() {
        for framework in ProjectFramework.allCases {
            let identity = framework.visualIdentity
            XCTAssertFalse(
                identity.mark.isEmpty && identity.systemImage == nil,
                "\(framework.rawValue) needs a mark or symbol"
            )
            if let tintHex = identity.tintHex {
                XCTAssertEqual(tintHex.count, 6, "\(framework.rawValue) needs a six-digit tint")
                XCTAssertNotNil(Int(tintHex, radix: 16), "\(framework.rawValue) has an invalid tint")
            }
        }
    }

    private func makeProject(named name: String, marker: String) throws -> URL {
        let root = temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "marker".write(to: root.appending(path: marker), atomically: true, encoding: .utf8)
        return root
    }
}
