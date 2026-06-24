import Foundation

struct DetailFileMetadata: Equatable, Sendable {
    let exists: Bool
    let bytes: Int64
    let modifiedAt: Date?
    let displayName: String?
    let parentDisplayName: String?

    static func load(for url: URL, precomputedBytes: Int64? = nil) -> DetailFileMetadata {
        let fileManager = FileManager.default
        let exists = fileManager.fileExists(atPath: url.path)
        guard exists else {
            return DetailFileMetadata(
                exists: false,
                bytes: 0,
                modifiedAt: nil,
                displayName: nil,
                parentDisplayName: nil
            )
        }

        let bytes: Int64 = precomputedBytes ?? StorageFormatting.itemSize(at: url)
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return DetailFileMetadata(
            exists: true,
            bytes: bytes,
            modifiedAt: values?.contentModificationDate,
            displayName: simulatorDisplayName(at: url),
            parentDisplayName: simulatorRuntimeName(at: url)
        )
    }

    private static func simulatorDisplayName(at url: URL) -> String? {
        simulatorPlistValue(at: url, key: "name")
    }

    private static func simulatorRuntimeName(at url: URL) -> String? {
        guard let runtime = simulatorPlistValue(at: url, key: "runtime") else { return nil }
        return runtime
            .split(separator: ".")
            .last?
            .replacingOccurrences(of: "SimRuntime-", with: "")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func simulatorPlistValue(at url: URL, key: String) -> String? {
        guard url.deletingLastPathComponent().lastPathComponent == "Devices" else { return nil }
        let plistURL = url.appendingPathComponent("device.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let dictionary = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else { return nil }
        return dictionary[key] as? String
    }
}
