import AppKit
import XCTest
@testable import StorageCleaner

final class MediaThumbnailProviderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMissingFileReturnsNil() async {
        let url = root.appendingPathComponent("does-not-exist.png")
        let result = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 100)
        XCTAssertNil(result)
    }

    func testRealPNGProducesAThumbnail() async throws {
        let url = root.appendingPathComponent("sample.png")
        try makeTestPNG(width: 256, height: 256).write(to: url)

        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 100)
        XCTAssertNotNil(image)
    }

    func testCacheReturnsSameImageForSameKey() async throws {
        let url = root.appendingPathComponent("cached.png")
        try makeTestPNG(width: 64, height: 64).write(to: url)

        let first = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 50)
        let second = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 50)
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second, "Cached thumbnail should be the same object")
    }

    func testRealJPEGProducesAThumbnail() async throws {
        let url = root.appendingPathComponent("sample.jpg")
        try makeTestJPEG(width: 200, height: 200).write(to: url)

        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 80)
        XCTAssertNotNil(image)
    }

    func testSVGFallsBackToRenderer() async throws {
        let url = root.appendingPathComponent("vector.svg")
        let svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
          <circle cx="50" cy="50" r="40" fill="green"/>
        </svg>
        """
        try svg.data(using: .utf8)?.write(to: url)

        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 100)
        XCTAssertNotNil(image, "SVG should fall back to the renderer and produce a bitmap")
    }

    func testBrokenPNGReturnsNil() async throws {
        let url = root.appendingPathComponent("broken.png")
        try Data([0x42, 0x42, 0x42, 0x42]).write(to: url)

        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 80)
        XCTAssertNil(image)
    }

    func testFallbackChainIsExercisedForUnsupportedFile() async throws {
        let url = root.appendingPathComponent("data.dat")
        try Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]).write(to: url)

        let image = await MediaThumbnailProvider.shared.thumbnail(for: url, sideLength: 80)
        XCTAssertNil(image, "Unknown binary formats should not produce a thumbnail")
    }

    func testThumbnailGenerationAcquiresAndReleasesPermissionScope() async throws {
        let url = root.appendingPathComponent("scoped.dat")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        let handler = RecordingPermissionHandler()

        _ = await MediaThumbnailProvider.shared.generateThumbnail(
            for: url,
            sideLength: 80,
            scale: 2,
            permissionHandler: handler
        )

        XCTAssertEqual(handler.beginCount, 1)
        XCTAssertEqual(handler.stopCount, 1)
    }

    private func makeTestPNG(width: Int, height: Int) -> Data {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return Data()
        }
        return png
    }

    private func makeTestJPEG(width: Int, height: Int, quality: CGFloat = 0.85) -> Data {
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            return Data()
        }
        return jpeg
    }
}

private final class RecordingPermissionHandler: @unchecked Sendable, StoragePermissionHandling {
    private let lock = NSLock()
    private var beginAccessCount = 0
    private var stopAccessCount = 0

    var beginCount: Int { lock.withLock { beginAccessCount } }
    var stopCount: Int { lock.withLock { stopAccessCount } }

    func currentStatuses() -> [StoragePermissionStatus] { [] }

    func beginHomeFolderAccess() -> SecurityScopedResourceAccess? {
        lock.withLock { beginAccessCount += 1 }
        return SecurityScopedResourceAccess(onStop: { [weak self] in
            guard let self else { return }
            self.lock.withLock {
                self.stopAccessCount += 1
            }
        })
    }
}
