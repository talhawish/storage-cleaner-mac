import Foundation
import XCTest
@testable import StorageCleaner

final class InstalledAppCatalogTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testCatalogAlwaysIncludesAppleSystemBundleIDs() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        for bundleID in SystemJunkPaths.appleBundleIDs {
            XCTAssertTrue(
                catalog.ownsLibraryEntry(named: bundleID),
                "Catalog should always include Apple bundle ID \(bundleID)"
            )
        }
    }

    func testCatalogAlwaysIncludesDevToolBundleIDs() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        for bundleID in SystemJunkPaths.alwaysInstalledBundleIDs {
            XCTAssertTrue(
                catalog.ownsLibraryEntry(named: bundleID),
                "Catalog should always include dev tool bundle ID \(bundleID)"
            )
        }
    }

    func testCatalogDiscoversBundleIDsFromAppBundles() throws {
        let bundleID = "com.example.MyInstalledApp"
        let appName = "MyInstalledApp"
        try writeApp(named: appName, bundleID: bundleID, in: temporaryDirectory)

        let catalog = InstalledAppCatalog(searchRoots: [temporaryDirectory])

        XCTAssertTrue(
            catalog.ownsLibraryEntry(named: bundleID),
            "Catalog should pick up the installed .app's CFBundleIdentifier"
        )
        XCTAssertTrue(
            catalog.ownsLibraryEntry(named: appName),
            "Catalog should pick up the installed .app's CFBundleName"
        )
    }

    func testCatalogHandlesMalformedAppBundlesGracefully() throws {
        // An .app folder with no Info.plist must not crash or fail the scan.
        let malformed = temporaryDirectory.appending(path: "MalformedApp.app")
        let contents = malformed.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data().write(to: contents.appending(path: "garbage"))

        let catalog = InstalledAppCatalog(searchRoots: [temporaryDirectory])

        XCTAssertFalse(catalog.bundleIDs.isEmpty, "Catalog should still have the Apple baseline")
    }

    func testCatalogSkipsNonAppDirectories() throws {
        let looseDirectory = temporaryDirectory.appending(path: "LooseFolder")
        try FileManager.default.createDirectory(at: looseDirectory, withIntermediateDirectories: true)

        let catalog = InstalledAppCatalog(searchRoots: [temporaryDirectory])

        XCTAssertFalse(
            catalog.ownsLibraryEntry(named: "LooseFolder"),
            "Loose folders should not be treated as apps"
        )
    }

    func testCatalogHandlesMissingRoot() {
        let missing = temporaryDirectory.appending(path: "DoesNotExist")
        let catalog = InstalledAppCatalog(searchRoots: [missing])

        XCTAssertFalse(catalog.bundleIDs.isEmpty, "Apple baseline should still be present")
    }

    func testOwnsLibraryEntryMatchesBundleID() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        XCTAssertTrue(catalog.ownsLibraryEntry(named: "com.apple.Safari"))
        XCTAssertTrue(catalog.ownsLibraryEntry(named: "com.apple.dt.Xcode"))
    }

    func testOwnsLibraryEntryMatchesDirectoryName() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        // The Apple baseline includes "Xcode" via reservedSupportDirectoryNames.
        XCTAssertTrue(catalog.ownsLibraryEntry(named: "Xcode"))
        XCTAssertTrue(catalog.ownsLibraryEntry(named: "CloudDocs"))
    }

    func testOwnsLibraryEntryIsCaseInsensitive() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        XCTAssertTrue(catalog.ownsLibraryEntry(named: "COM.APPLE.SAFARI"))
        XCTAssertTrue(catalog.ownsLibraryEntry(named: "xcode"))
    }

    func testOwnsLibraryEntryRejectsOrphans() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        XCTAssertFalse(catalog.ownsLibraryEntry(named: "DefinitelyNotAnInstalledApp"))
        XCTAssertFalse(catalog.ownsLibraryEntry(named: "UninstalledLongAgo"))
    }

    func testOwnsLibraryEntryRejectsEmptyAndHidden() {
        let catalog = InstalledAppCatalog(searchRoots: [])

        XCTAssertFalse(catalog.ownsLibraryEntry(named: ""))
    }

    func testDirectoryNameProjectionForBundleID() {
        XCTAssertEqual(InstalledAppCatalog.directoryName(for: "com.example.MyApp"), "MyApp")
        XCTAssertEqual(InstalledAppCatalog.directoryName(for: "com.apple.Safari"), "Safari")
        XCTAssertEqual(InstalledAppCatalog.directoryName(for: "single"), "single")
    }

    // MARK: - Helpers

    private func writeApp(named name: String, bundleID: String, in parent: URL) throws {
        let appURL = parent.appending(path: "\(name).app")
        let contents = appURL.appending(path: "Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appending(path: "Info.plist"))
    }
}
