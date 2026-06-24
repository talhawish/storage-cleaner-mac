import Foundation

struct FindingFileRecord: Identifiable, Equatable, Sendable {
    struct RecordID: Hashable, Sendable {
        let kind: StorageFindingKind
        let url: URL
    }

    let url: URL
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64
    let exists: Bool
    let modifiedAt: Date?

    var id: RecordID { RecordID(kind: kind, url: url) }

    var detailMetadata: DetailFileMetadata {
        DetailFileMetadata(
            exists: exists,
            bytes: bytes,
            modifiedAt: modifiedAt,
            displayName: nil,
            parentDisplayName: nil
        )
    }
}

struct FindingFileRecordMetadata: Equatable, Sendable {
    let exists: Bool
    let bytes: Int64
    let modifiedAt: Date?

    static func load(for url: URL) -> FindingFileRecordMetadata {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path)
        guard exists else {
            return FindingFileRecordMetadata(exists: false, bytes: 0, modifiedAt: nil)
        }

        return FindingFileRecordMetadata(
            exists: true,
            bytes: StorageFormatting.itemSize(at: url),
            modifiedAt: StorageFormatting.modificationDate(at: url)
        )
    }
}

enum FindingFileRecordBuilder {
    static func records(
        from findings: [StorageFinding],
        loadMetadata: (URL) -> FindingFileRecordMetadata = FindingFileRecordMetadata.load(for:)
    ) -> [FindingFileRecord] {
        findings.flatMap { finding in
            finding.filePaths.map { url in
                let metadata = loadMetadata(url)
                return FindingFileRecord(
                    url: url,
                    kind: finding.kind,
                    domain: finding.domain,
                    bytes: metadata.bytes,
                    exists: metadata.exists,
                    modifiedAt: metadata.modifiedAt
                )
            }
        }
    }

    static func totalSelectedBytes(selectedURLs: Set<URL>, records: [FindingFileRecord]) -> Int64 {
        var bytesByURL: [URL: Int64] = [:]
        for record in records where bytesByURL[record.url] == nil {
            bytesByURL[record.url] = record.bytes
        }

        return selectedURLs.reduce(Int64(0)) { total, url in
            total + (bytesByURL[url] ?? 0)
        }
    }
}

struct FindingFileRecordsIdentity: Hashable {
    private let entries: [Entry]

    init(findings: [StorageFinding]) {
        entries = findings.flatMap { finding in
            finding.filePaths.map { Entry(kind: finding.kind, path: $0.standardizedFileURL.path) }
        }
    }

    private struct Entry: Hashable {
        let kind: StorageFindingKind
        let path: String
    }
}
