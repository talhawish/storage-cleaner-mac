import Foundation

enum StorageFormatting {
    static func bytes(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: value)
    }

    static func bytes(_ value: Int) -> String {
        bytes(Int64(value))
    }

    static func items(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func duration(_ value: Duration) -> String {
        let seconds = max(value.components.seconds, 1)
        return "\(seconds)s"
    }

    static func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileAllocatedSizeKey, .fileSizeKey])
        return Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }

    static func modificationDate(at url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
