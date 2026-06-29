import Foundation
import XCTest
@testable import StorageCleaner

final class FileSystemPermissionServiceTests: XCTestCase {
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

    @MainActor
    func testStoresHomeChildBookmarks() throws {
        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        try createStandardHomeFolders(at: home)
        let store = InMemoryBookmarkDataStore()
        let service = FileSystemPermissionService(
            bookmarkStore: store,
            picker: FixedHomeFolderPicker(selectedURL: home),
            homeDirectory: home
        )

        XCTAssertTrue(service.requestHomeFolderAccess())
        XCTAssertEqual(service.currentStatuses().first?.state, .accessible)
    }

    func testAcceptsHomeOnlyBookmark() throws {
        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let store = InMemoryBookmarkDataStore()
        let homeBookmark = try home.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        store.set(homeBookmark, forKey: "HomeFolderSecurityScopedBookmark")
        let service = FileSystemPermissionService(
            bookmarkStore: store,
            picker: FixedHomeFolderPicker(selectedURL: home),
            homeDirectory: home
        )

        XCTAssertEqual(service.currentStatuses().first?.state, .accessible)
        let access = service.beginHomeFolderAccess()
        XCTAssertNotNil(access)
        access?.stop()
    }

    func testStaleBookmarkIsDetectedViaDirectoryProbe() throws {
        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let store = InMemoryBookmarkDataStore()
        let homeBookmark = try home.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        store.set(homeBookmark, forKey: "HomeFolderSecurityScopedBookmark")
        let service = FileSystemPermissionService(
            bookmarkStore: store,
            picker: FixedHomeFolderPicker(selectedURL: home),
            homeDirectory: home
        )

        // Sanity check: access works when directory is readable.
        XCTAssertNotNil(service.beginHomeFolderAccess())

        // Revoke access by making the directory unreadable.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: home.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: home.path) }

        // beginHomeFolderAccess must detect the denial and return nil.
        XCTAssertNil(service.beginHomeFolderAccess())

        // Stale bookmarks must be cleaned up.
        XCTAssertNil(store.data(forKey: "HomeFolderSecurityScopedBookmark"))
    }

    @MainActor
    func testRequestSucceedsWhenStandardChildFoldersAreMissing() throws {
        let home = temporaryDirectory.appending(path: "home", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let service = FileSystemPermissionService(
            bookmarkStore: InMemoryBookmarkDataStore(),
            picker: FixedHomeFolderPicker(selectedURL: home),
            homeDirectory: home
        )

        XCTAssertTrue(service.requestHomeFolderAccess())
        XCTAssertEqual(service.currentStatuses().first?.state, .accessible)
    }

    private func createStandardHomeFolders(at home: URL) throws {
        for relativePath in ["Desktop", "Documents", "Downloads", "Pictures", "Movies", "Library", ".Trash"] {
            try FileManager.default.createDirectory(
                at: home.appending(path: relativePath, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
    }
}

private struct FixedHomeFolderPicker: HomeFolderPicking {
    let selectedURL: URL?

    @MainActor
    func pickHomeFolder(defaultURL: URL) -> URL? {
        selectedURL
    }
}

private final class InMemoryBookmarkDataStore: @unchecked Sendable, BookmarkDataStoring {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        lock.withLock {
            values[key]
        }
    }

    func set(_ value: Data, forKey key: String) {
        lock.withLock {
            values[key] = value
        }
    }

    func removeObject(forKey key: String) {
        _ = lock.withLock {
            values.removeValue(forKey: key)
        }
    }
}
