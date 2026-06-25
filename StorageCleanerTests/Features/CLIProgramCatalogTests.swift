import Foundation
import XCTest
@testable import StorageCleaner

final class CLIProgramCatalogTests: XCTestCase {
    /// Every path the CLI scanner inspects must resolve to a recognized program,
    /// not the generic fallback. Guards against the catalog drifting from
    /// `DependencyPaths.CLI`.
    func testEveryScannedRootResolvesToARecognizedProgram() {
        let roots = DependencyPaths.CLI.homeDirs + DependencyPaths.CLI.systemDirs

        for url in roots {
            let program = CLIProgramCatalog.descriptor(for: url)
            XCTAssertNotEqual(
                program.subtitle,
                "Command-line tool data",
                "\(url.lastPathComponent) fell through to the fallback descriptor"
            )
            XCTAssertFalse(program.displayName.isEmpty)
        }
    }

    func testHomebrewCacheIsSafeToClean() {
        let url = DependencyPaths.home("Library/Caches/Homebrew")
        let program = CLIProgramCatalog.descriptor(for: url)
        XCTAssertEqual(program.safety, .safe)
        XCTAssertEqual(program.category, .homebrew)
    }

    func testInstalledToolchainRequiresReview() {
        let program = CLIProgramCatalog.descriptor(for: DependencyPaths.home(".rustup"))
        XCTAssertEqual(program.safety, .review)
        XCTAssertEqual(program.displayName, "Rustup")
    }

    func testCellarResolvesForBothHomebrewPrefixes() {
        let appleSilicon = URL(fileURLWithPath: "/opt/homebrew/Cellar", isDirectory: true)
        let intel = URL(fileURLWithPath: "/usr/local/Cellar", isDirectory: true)
        XCTAssertEqual(CLIProgramCatalog.descriptor(for: appleSilicon).displayName, "Homebrew formulae")
        XCTAssertEqual(CLIProgramCatalog.descriptor(for: intel).displayName, "Homebrew formulae")
    }

    func testUnknownRootUsesReadableFallbackName() {
        let url = URL(fileURLWithPath: "/Users/test/.someobscuretool", isDirectory: true)
        let program = CLIProgramCatalog.descriptor(for: url)
        XCTAssertEqual(program.displayName, "someobscuretool")
        XCTAssertEqual(program.safety, .review)
    }

    func testHomebrewCellarExpandsIntoOneProgramPerFormula() throws {
        let cellar = try makeTempDirectory(named: "Cellar")
        for formula in ["git", "node", "wget"] {
            try FileManager.default.createDirectory(
                at: cellar.appendingPathComponent(formula),
                withIntermediateDirectories: true
            )
        }

        let programs = CLIProgramCatalog.expand(root: cellar)
        XCTAssertEqual(Set(programs.map(\.displayName)), ["git", "node", "wget"])
        XCTAssertTrue(programs.allSatisfy { $0.category == .homebrew })
    }

    func testEmptyContainerFallsBackToRootRow() throws {
        let cellar = try makeTempDirectory(named: "Cellar")
        let programs = CLIProgramCatalog.expand(root: cellar)
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs.first?.displayName, "Homebrew formulae")
    }

    func testCanonicalRootsIncludesCargoAndBunBins() {
        // These paths are in DependencyPaths.CLI.homeDirs and must be
        // reflected in canonicalRoots so the independent CLI Programs
        // screen discovers Rust- and Bun-installed binaries.
        let roots = CLIProgramCatalog.canonicalRoots
        XCTAssertTrue(roots.contains { $0.path.hasSuffix(".cargo/bin") }, ".cargo/bin missing from canonicalRoots")
        XCTAssertTrue(roots.contains { $0.path.hasSuffix(".bun/bin") }, ".bun/bin missing from canonicalRoots")
    }

    func testNonContainerRootStaysASingleProgram() {
        let programs = CLIProgramCatalog.expand(root: DependencyPaths.home(".rustup"))
        XCTAssertEqual(programs.count, 1)
        XCTAssertEqual(programs.first?.displayName, "Rustup")
    }

    private func makeTempDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        return url
    }
}
