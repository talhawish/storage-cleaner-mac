import Foundation

enum StorageFormatting {
    static func bytes(_ value: Int64) -> String {
        guard value > 0 else { return "0 KB" }

        let formatter = ByteCountFormatter()
        // Include KB/bytes so small tools (e.g. a few-KB shell script) don't render
        // as "0 MB". isAdaptive keeps large values at GB/MB.
        formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
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

    /// Returns the on-disk size of an item, recursing into directories.
    ///
    /// `fileSize(at:)` only reports the size of the inode itself, so it is wrong
    /// for directories (e.g. CLI toolchain roots). Use this when the URL may be a
    /// folder. Run off the main thread — it can enumerate large trees.
    static func itemSize(at url: URL) -> Int64 {
        let sizeKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .fileSizeKey]
        let values = try? url.resourceValues(forKeys: sizeKeys)
        if values?.isRegularFile == true {
            return Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
        }

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(sizeKeys),
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            let childValues = try? child.resourceValues(forKeys: sizeKeys)
            guard childValues?.isRegularFile == true else { continue }
            total += Int64(childValues?.fileAllocatedSize ?? childValues?.fileSize ?? 0)
        }
        return total
    }

    static func modificationDate(at url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
