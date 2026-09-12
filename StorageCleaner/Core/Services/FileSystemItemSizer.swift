import Foundation

/// Measures reclaimable allocated bytes without retaining an entire directory
/// tree. Foundation directory enumeration creates autoreleased URL/resource
/// objects; draining them once per item keeps multi-million-file trees from
/// growing the process until the scan completes.
enum FileSystemItemSizer {
    static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .fileAllocatedSizeKey,
        .fileSizeKey
    ]

    static func allocatedSize(
        of url: URL,
        fileManager: FileManager = .default,
        options: FileManager.DirectoryEnumerationOptions = []
    ) -> Int64 {
        let values = try? url.resourceValues(forKeys: resourceKeys)
        if values?.isRegularFile == true {
            return allocatedSize(from: values)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options
        ) else {
            return 0
        }

        var total: Int64 = 0
        while !Task.isCancelled {
            let nextSize: Int64? = autoreleasepool {
                guard let child = enumerator.nextObject() as? URL else { return nil }
                let childValues = try? child.resourceValues(forKeys: resourceKeys)
                guard childValues?.isRegularFile == true else { return 0 }
                return allocatedSize(from: childValues)
            }
            guard let nextSize else { break }
            total = total.addingReportingOverflow(nextSize).overflow ? Int64.max : total + nextSize
        }
        return total
    }

    static func allocatedSize(from values: URLResourceValues?) -> Int64 {
        Int64(values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }
}
