import Foundation
import XCTest
@testable import StorageCleaner

final class SystemJunkScannersTests: XCTestCase {
    private var temporaryLibrary: URL!
    private var collector: FileSystemCollector!
    private var catalog: StubOrphanCatalog!

    override func setUpWithError() throws {
        temporaryLibrary = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryLibrary,
            withIntermediateDirectories: true
        )
        collector = FileSystemCollector()

        // Fixed "installed" set so results are deterministic regardless of the test host.
        catalog = StubOrphanCatalog(installed: [
            "com.example.InstalledApp": ["InstalledApp"],
            "com.apple.Safari": ["Safari"],
            "com.installed.primary": nil,
            "group.com.installed": nil
        ])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryLibrary)
    }

    // MARK: - Orphaned Application Support

    func testOrphanedAppSupportFindsDirectoriesNotInCatalog() async throws {
        try makeDirectory(relativeTo: "Application Support/OrphanedTool")
        try makeDirectory(relativeTo: "Application Support/InstalledApp")
        try makeDirectory(relativeTo: "Application Support/Safari")
        try writeBytes(1024, to: "Application Support/OrphanedTool/data.bin")

        let scanner = OrphanedAppSupportScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Application Support")
        )
        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .orphanedAppSupport)
        XCTAssertEqual(finding.domain, .systemJunk)
        XCTAssertEqual(finding.safety, .review)
        XCTAssertEqual(finding.itemCount, 1)
        XCTAssertEqual(finding.filePaths.map(\.lastPathComponent), ["OrphanedTool"])
        XCTAssertGreaterThan(finding.bytes, 0)
    }

    func testOrphanedAppSupportReturnsNilWhenAllOwned() async throws {
        try makeDirectory(relativeTo: "Application Support/InstalledApp")
        try makeDirectory(relativeTo: "Application Support/Safari")

        let scanner = OrphanedAppSupportScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Application Support")
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    func testOrphanedAppSupportReturnsNilWhenRootMissing() async throws {
        let scanner = OrphanedAppSupportScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Application Support")
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    // MARK: - Orphaned Caches

    func testOrphanedAppCachesFindsDirectoriesNotInCatalog() async throws {
        try makeDirectory(relativeTo: "Caches/OrphanedCaches")
        try makeDirectory(relativeTo: "Caches/InstalledApp")
        try writeBytes(2048, to: "Caches/OrphanedCaches/cache.bin")

        let scanner = OrphanedAppCachesScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Caches")
        )
        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .orphanedAppCaches)
        XCTAssertEqual(finding.safety, .safe)
        XCTAssertEqual(finding.itemCount, 1)
        XCTAssertEqual(finding.filePaths.map(\.lastPathComponent), ["OrphanedCaches"])
    }

    // MARK: - Orphaned Containers

    func testOrphanedAppContainersFindsAcrossBothRoots() async throws {
        try makeDirectory(relativeTo: "Containers/com.orphan.primary")
        try makeDirectory(relativeTo: "Containers/com.installed.primary")
        try makeDirectory(relativeTo: "Group Containers/group.com.orphan")
        try makeDirectory(relativeTo: "Group Containers/group.com.installed")
        try writeBytes(512, to: "Containers/com.orphan.primary/data.bin")
        try writeBytes(512, to: "Group Containers/group.com.orphan/data.bin")

        let scanner = OrphanedAppContainersScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Containers"),
            groupContainersRoot: temporaryLibrary.appending(path: "Group Containers")
        )
        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .orphanedAppContainers)
        XCTAssertEqual(finding.itemCount, 2)
        let names = Set(finding.filePaths.map(\.lastPathComponent))
        XCTAssertEqual(names, ["com.orphan.primary", "group.com.orphan"])
    }

    func testOrphanedAppContainersSkipsOwned() async throws {
        try makeDirectory(relativeTo: "Containers/com.installed.primary")
        try makeDirectory(relativeTo: "Group Containers/group.com.installed")

        let scanner = OrphanedAppContainersScanner(
            collector: collector,
            catalog: catalog,
            root: temporaryLibrary.appending(path: "Containers"),
            groupContainersRoot: temporaryLibrary.appending(path: "Group Containers")
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    // MARK: - Orphaned Preferences

    func testOrphanedPreferencesFindsUnownedPlists() async throws {
        try writePlist(named: "com.example.InstalledApp.plist", in: "Preferences")
        try writePlist(named: "com.apple.Safari.plist", in: "Preferences")
        try writePlist(named: "com.orphan.gone.plist", in: "Preferences")
        try write("notes.txt", in: "Preferences")

        let scanner = OrphanedPreferencesScanner(
            catalog: catalog,
            collector: collector,
            root: temporaryLibrary.appending(path: "Preferences")
        )
        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .orphanedAppPreferences)
        XCTAssertEqual(finding.itemCount, 1)
        XCTAssertEqual(finding.filePaths.map(\.lastPathComponent), ["com.orphan.gone.plist"])
    }

    func testOrphanedPreferencesSkipsOwnedPlists() async throws {
        try writePlist(named: "com.example.InstalledApp.plist", in: "Preferences")
        try writePlist(named: "com.apple.Safari.plist", in: "Preferences")

        let scanner = OrphanedPreferencesScanner(
            catalog: catalog,
            collector: collector,
            root: temporaryLibrary.appending(path: "Preferences")
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    func testOrphanedPreferencesIgnoresNonPlistFiles() async throws {
        try write("not-a-plist.txt", in: "Preferences", bytes: 128)
        try write("still-not-a-plist.json", in: "Preferences", bytes: 128)

        let scanner = OrphanedPreferencesScanner(
            catalog: catalog,
            collector: collector,
            root: temporaryLibrary.appending(path: "Preferences")
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    // MARK: - Old crash reports

    func testOldCrashReportsFindsAllSupportedExtensions() async throws {
        try writeBytes(1024, to: "Logs/DiagnosticReports/Foo.crash")
        try writeBytes(2048, to: "Logs/DiagnosticReports/Bar.ips")
        try writeBytes(512, to: "Logs/CrashReporter/Baz.synced")
        try writeBytes(256, to: "Logs/DiagnosticReports/Watchdog.diag")
        try writeBytes(256, to: "Logs/DiagnosticReports/Kernel.panic")
        try writeBytes(256, to: "Logs/DiagnosticReports/Sampler.spin")
        try writeBytes(256, to: "Logs/DiagnosticReports/App.hang")
        try writeBytes(256, to: "Logs/DiagnosticReports/Memory.memory")
        try writeBytes(128, to: "Logs/DiagnosticReports/notes.txt")

        let scanner = OldCrashReportsScanner(
            collector: collector,
            roots: [
                temporaryLibrary.appending(path: "Logs/DiagnosticReports"),
                temporaryLibrary.appending(path: "Logs/CrashReporter")
            ]
        )
        let result = await scanner.scan()

        let finding = try XCTUnwrap(result.finding)
        XCTAssertEqual(finding.kind, .oldCrashReports)
        XCTAssertEqual(finding.domain, .systemJunk)
        XCTAssertEqual(finding.safety, .safe)
        XCTAssertEqual(finding.itemCount, 8)
        let names = Set(finding.filePaths.map(\.lastPathComponent))
        XCTAssertEqual(
            names,
            [
                "App.hang",
                "Bar.ips",
                "Baz.synced",
                "Foo.crash",
                "Kernel.panic",
                "Memory.memory",
                "Sampler.spin",
                "Watchdog.diag"
            ]
        )
        XCTAssertGreaterThan(finding.bytes, 1024)
    }

    func testOldCrashReportsReturnsNilWhenNoReports() async throws {
        try writeBytes(128, to: "Logs/DiagnosticReports/notes.txt")

        let scanner = OldCrashReportsScanner(
            collector: collector,
            roots: [
                temporaryLibrary.appending(path: "Logs/DiagnosticReports"),
                temporaryLibrary.appending(path: "Logs/CrashReporter")
            ]
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    func testOldCrashReportsReturnsNilWhenDiagnosticDirectoryMissing() async throws {
        let scanner = OldCrashReportsScanner(
            collector: collector,
            roots: [
                temporaryLibrary.appending(path: "Logs/DiagnosticReports"),
                temporaryLibrary.appending(path: "Logs/CrashReporter")
            ]
        )
        let result = await scanner.scan()

        XCTAssertNil(result.finding)
    }

    // MARK: - Helpers

    private func makeDirectory(relativeTo path: String) throws {
        let url = temporaryLibrary.appending(path: path)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    private func writeBytes(_ count: Int, to path: String) throws {
        let url = temporaryLibrary.appending(path: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: count).write(to: url)
    }

    private func writePlist(named name: String, in folder: String) throws {
        let url = temporaryLibrary.appending(path: folder).appending(path: name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = ["test": true]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: url)
    }

    private func write(_ name: String, in folder: String, bytes: Int = 64) throws {
        let url = temporaryLibrary.appending(path: folder).appending(path: name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: bytes).write(to: url)
    }
}

/// Test catalog whose "installed" set is fixed to whatever fixtures the test injects — independent
/// of the real `InstalledAppCatalog` so tests are deterministic and isolated from the host machine.
private struct StubOrphanCatalog: OrphanCatalog {
    let installed: [String: [String]?]

    func ownsLibraryEntry(named entryName: String) -> Bool {
        let lower = entryName.lowercased()
        for (bundleID, names) in installed {
            if bundleID.lowercased() == lower { return true }
            for name in names ?? [] where name.lowercased() == lower { return true }
        }
        return false
    }
}
