import AppKit
import XCTest
@testable import StorageCleaner

final class ImageMetadataLoaderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testLoadReturnsUnknownForMissingFile() {
        let url = root.appendingPathComponent("does-not-exist.png")
        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertFalse(metadata.isKnown)
        XCTAssertEqual(metadata.pixelWidth, 0)
        XCTAssertEqual(metadata.pixelHeight, 0)
    }

    func testLoadReturnsUnknownForCorruptFile() throws {
        let url = root.appendingPathComponent("not-an-image.png")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: url)
        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertFalse(metadata.isKnown)
    }

    func testLoadReadsRealPNGDimensions() throws {
        let url = root.appendingPathComponent("sample.png")
        let image = makeTestPNG(width: 64, height: 32)
        try image.write(to: url)
        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertTrue(metadata.isKnown)
        XCTAssertEqual(metadata.pixelWidth, 128, "Retina bitmap is 2x the logical size")
        XCTAssertEqual(metadata.pixelHeight, 64)
        XCTAssertGreaterThan(metadata.bitDepth ?? 0, 0)
    }

    func testLoadAsyncReturnsTheSameValue() async throws {
        let url = root.appendingPathComponent("async.png")
        let image = makeTestPNG(width: 100, height: 50)
        try image.write(to: url)

        let metadata = await ImageMetadataLoader.load(for: url)
        XCTAssertEqual(metadata.pixelWidth, 200)
        XCTAssertEqual(metadata.pixelHeight, 100)
    }

    func testLoadSVGFallsBackToXMLParsing() throws {
        let url = root.appendingPathComponent("vector.svg")
        let svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="128" height="64" viewBox="0 0 128 64">
          <rect width="128" height="64" fill="red"/>
        </svg>
        """
        try svg.data(using: .utf8)?.write(to: url)

        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertTrue(metadata.isKnown)
        XCTAssertEqual(metadata.pixelWidth, 128)
        XCTAssertEqual(metadata.pixelHeight, 64)
    }

    func testLoadSVGUsesViewBoxWhenWidthAndHeightAreOmitted() throws {
        let url = root.appendingPathComponent("viewbox.svg")
        let svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100">
          <rect width="200" height="100" fill="blue"/>
        </svg>
        """
        try svg.data(using: .utf8)?.write(to: url)

        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertTrue(metadata.isKnown)
        XCTAssertEqual(metadata.pixelWidth, 200)
        XCTAssertEqual(metadata.pixelHeight, 100)
    }

    func testLoadSVGReturnsUnknownForMissingDimensions() throws {
        let url = root.appendingPathComponent("no-dims.svg")
        let svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect/>
        </svg>
        """
        try svg.data(using: .utf8)?.write(to: url)

        let metadata = ImageMetadataLoader.loadSync(for: url)
        XCTAssertFalse(metadata.isKnown)
    }

    func testAspectRatioReducesByGCD() {
        let landscape = makeMetadata(width: 1920, height: 1080)
        XCTAssertEqual(landscape.aspectRatioDescription, "16:9")

        let portrait = makeMetadata(width: 1080, height: 1920)
        XCTAssertEqual(portrait.aspectRatioDescription, "9:16")

        let square = makeMetadata(width: 512, height: 512)
        XCTAssertEqual(square.aspectRatioDescription, "1:1")
    }

    func testAspectRatioIsNilForUnknownDimensions() {
        XCTAssertNil(ImageMetadata.unknown.aspectRatioDescription)
    }

    func testDimensionsDescriptionFormatsWidthAndHeight() {
        let metadata = makeMetadata(width: 1920, height: 1080)
        XCTAssertEqual(metadata.dimensionsDescription, "1920 × 1080")
        XCTAssertEqual(ImageMetadata.unknown.dimensionsDescription, "Unknown dimensions")
    }

    private func makeMetadata(width: Int, height: Int) -> ImageMetadata {
        ImageMetadata(
            pixelWidth: width,
            pixelHeight: height,
            colorSpaceName: nil,
            bitDepth: nil,
            hasAlpha: false,
            creationDate: nil,
            orientation: 1
        )
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
}
