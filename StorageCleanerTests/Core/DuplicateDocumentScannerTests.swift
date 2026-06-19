import Foundation
import XCTest
@testable import StorageCleaner

final class DuplicateDocumentScannerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    private func makeScanner(roots: [URL], minimumBytes: Int64 = 128) -> DuplicateMediaScanner {
        DuplicateMediaScanner(
            kind: .duplicateDocuments,
            domain: .documents,
            roots: roots,
            extensions: DependencyPaths.Documents.documentExtensions,
            minimumBytes: minimumBytes,
            collector: FileSystemCollector()
        )
    }

    func testFindsDuplicatePDFsAcrossDocumentFolders() async throws {
        let documents = temporaryDirectory.appending(path: "Documents", directoryHint: .isDirectory)
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let payload = Data(repeating: 7, count: 40_000)

        try payload.write(to: documents.appending(path: "invoice.pdf"))
        try payload.write(to: downloads.appending(path: "invoice copy.pdf"))
        try Data(repeating: 8, count: 40_000).write(to: downloads.appending(path: "other.pdf"))

        let result = await makeScanner(roots: [documents, downloads]).scan()

        XCTAssertEqual(result.finding?.kind, .duplicateDocuments)
        XCTAssertEqual(result.finding?.domain, .documents)
        XCTAssertEqual(result.finding?.itemCount, 1)
        XCTAssertEqual(result.finding?.bytes, 40_960)

        let group = try XCTUnwrap(result.finding?.duplicateGroups.first)
        XCTAssertEqual(group.files.count, 2)
        XCTAssertEqual(group.contentKind, .document)
        // The copy without a "copy" marker, in the curated Documents folder, is kept.
        XCTAssertEqual(group.keepURL.lastPathComponent, "invoice.pdf")
    }

    func testDetectsDuplicateSpreadsheetsAndArchives() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let csv = Data(repeating: 1, count: 30_000)
        let archive = Data(repeating: 2, count: 60_000)

        try csv.write(to: downloads.appending(path: "report.csv"))
        try csv.write(to: downloads.appending(path: "report (1).csv"))
        try archive.write(to: downloads.appending(path: "backup.zip"))
        try archive.write(to: downloads.appending(path: "backup copy.zip"))

        let result = await makeScanner(roots: [downloads]).scan()

        let groups = try XCTUnwrap(result.finding?.duplicateGroups)
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(result.finding?.itemCount, 2)
        XCTAssertTrue(groups.allSatisfy { $0.contentKind == .document })
    }

    func testSkipsFilesBelowMinimumSize() async throws {
        let downloads = temporaryDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let tiny = Data(repeating: 5, count: 10_000)

        try tiny.write(to: downloads.appending(path: "note.txt"))
        try tiny.write(to: downloads.appending(path: "note copy.txt"))

        let result = await makeScanner(roots: [downloads], minimumBytes: 50_000).scan()

        XCTAssertNil(result.finding)
    }

    func testContentKindClassification() {
        XCTAssertEqual(DuplicateContentKind.forExtension("PDF"), .document)
        XCTAssertEqual(DuplicateContentKind.forExtension("svg"), .document)
        XCTAssertEqual(DuplicateContentKind.forExtension("zip"), .document)
        XCTAssertEqual(DuplicateContentKind.forExtension("xlsx"), .document)
        XCTAssertEqual(DuplicateContentKind.forExtension("mov"), .video)
        XCTAssertEqual(DuplicateContentKind.forExtension("png"), .image)
        XCTAssertEqual(DuplicateContentKind.document.stackSymbol, "doc.on.doc.fill")
    }
}
