import XCTest
@testable import StorageCleaner

final class MediaFileTypeTests: XCTestCase {
    func testRasterImageExtensionsAreClassifiedAsImage() {
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.png")),
            .rasterImage(format: .png)
        )
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.JPG")),
            .rasterImage(format: .jpeg)
        )
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.heic")),
            .rasterImage(format: .heic)
        )
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.webp")),
            .rasterImage(format: .webp)
        )
    }

    func testSVGIsClassifiedAsSVG() {
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.svg")),
            .svg
        )
    }

    func testVideoExtensionsAreClassifiedAsVideo() {
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.mp4")),
            .video
        )
        XCTAssertEqual(
            MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.mov")),
            .video
        )
    }

    func testPDFIsClassifiedAsOther() {
        let type = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.pdf"))
        guard case .other(let kind) = type else {
            return XCTFail("Expected .other kind, got \(type)")
        }
        XCTAssertEqual(kind, .pdf)
    }

    func testDocumentExtensionsAreClassifiedAsDocument() {
        let type = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.docx"))
        guard case .other(let kind) = type else {
            return XCTFail("Expected .other kind, got \(type)")
        }
        XCTAssertEqual(kind, .document)
    }

    func testInstallerExtensionsAreClassifiedAsInstaller() {
        let type = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.dmg"))
        guard case .other(let kind) = type else {
            return XCTFail("Expected .other kind, got \(type)")
        }
        XCTAssertEqual(kind, .installer)

        let apkType = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.apk"))
        guard case .other(let apkKind) = apkType else {
            return XCTFail("Expected .other kind, got \(apkType)")
        }
        XCTAssertEqual(apkKind, .installer)
    }

    func testArchiveExtensionsAreClassifiedAsArchive() {
        let type = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.zip"))
        guard case .other(let kind) = type else {
            return XCTFail("Expected .other kind, got \(type)")
        }
        XCTAssertEqual(kind, .archive)
    }

    func testUnknownExtensionFallsBackToBinary() {
        let type = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.xyz"))
        guard case .other(let kind) = type else {
            return XCTFail("Expected .other kind, got \(type)")
        }
        XCTAssertEqual(kind, .binary)
    }

    func testIsImageReflectsClassification() {
        XCTAssertTrue(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.png")).isImage)
        XCTAssertTrue(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.svg")).isImage)
        XCTAssertFalse(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.mp4")).isImage)
        XCTAssertFalse(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.zip")).isImage)
    }

    func testIsVideoReflectsClassification() {
        XCTAssertTrue(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.mp4")).isVideo)
        XCTAssertFalse(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.png")).isVideo)
    }

    func testIsSVGReflectsClassification() {
        XCTAssertTrue(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.svg")).isSVG)
        XCTAssertFalse(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.png")).isSVG)
    }

    func testDisplayNameIsHumanReadable() {
        XCTAssertEqual(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.png")).displayName, "PNG")
        XCTAssertEqual(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.svg")).displayName, "SVG")
        XCTAssertEqual(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.mp4")).displayName, "Video")
        XCTAssertEqual(MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.pdf")).displayName, "PDF")
    }

    func testSymbolNameReturnsNonEmpty() {
        let cases: [String] = ["png", "svg", "mp4", "pdf", "zip", "dmg", "mp3", "ttf", "exe", "xyz"]
        for ext in cases {
            let symbol = MediaFileType.classify(url: URL(fileURLWithPath: "/tmp/foo.\(ext)")).symbolName
            XCTAssertFalse(symbol.isEmpty, "Empty symbol for .\(ext)")
        }
    }
}
