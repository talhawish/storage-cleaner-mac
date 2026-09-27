import Foundation

/// Derived once when the scan findings change, with stable largest-first ordering.
struct StorageInventoryPresentation: Sendable {
    let items: [ReviewableStorageItem]
    let summary: String
    let reviewMessage: String

    init(findings: [StorageFinding] = []) {
        let paths: [ReviewableStorageItem] = findings.flatMap { finding in
            finding.filePaths.map { url in
                let bytes = finding.pathBytes[url] ?? (finding.filePaths.count == 1 ? finding.bytes : 0)
                return ReviewableStorageItem(finding: finding, url: url, bytes: bytes)
            }
        }
        items = paths.sorted {
            $0.bytes == $1.bytes ? $0.id < $1.id : $0.bytes > $1.bytes
        }
        let bytes = items.reduce(Int64(0)) { $0 + $1.bytes }
        summary = "\(StorageFormatting.items(items.count)) · \(StorageFormatting.bytes(bytes))"
        let containsModels = findings.contains { $0.kind == .localAIModels || $0.kind == .aiModelCaches }
        reviewMessage = containsModels
            ? "Keep models used by apps or extensions you rely on. Removing a weight file can stop a model "
                + "from working, even when other model files remain. These files are not known to be unused."
            : "These folders may contain active app or user data. Check each full path and its contents "
                + "before moving anything to the Trash."
    }
}

struct ReviewableStorageItem: Identifiable, Sendable {
    let finding: StorageFinding
    let url: URL
    let bytes: Int64

    var id: String { "\(finding.kind.rawValue):\(url.path)" }

    /// Opening one row must show only that item, with no other paths silently
    /// included in Select Visible or the removal preview.
    var detailFinding: StorageFinding {
        StorageFinding(
            kind: finding.kind,
            domain: finding.domain,
            bytes: bytes,
            itemCount: 1,
            safety: finding.safety,
            examples: [url.lastPathComponent],
            filePaths: [url],
            pathBytes: [url: bytes]
        )
    }

    var accessibilityLabel: String {
        "\(finding.kind.title), \(url.path), \(StorageFormatting.bytes(bytes)), review first"
    }
}
