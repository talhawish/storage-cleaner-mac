import Foundation

struct LargeFileScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .largeFiles
    let title = StorageFindingKind.largeFiles.title
    private let scanner: FilePatternScanner
    private let safetyPolicy: LargeFileSafetyPolicy

    init(
        roots: [URL] = [
            DependencyPaths.home("Desktop"),
            DependencyPaths.home("Downloads"),
            DependencyPaths.home("Documents"),
            DependencyPaths.home("Movies"),
            DependencyPaths.home("Pictures")
        ],
        minimumBytes: Int64 = 100_000_000,
        safetyPolicy: LargeFileSafetyPolicy = LargeFileSafetyPolicy(),
        collector: FileSystemCollector
    ) {
        self.safetyPolicy = safetyPolicy
        scanner = FilePatternScanner(
            kind: .largeFiles,
            domain: .otherCaches,
            roots: roots,
            safety: .review,
            collector: collector
        ) { url in
            safetyPolicy.isReviewSafeCandidate(url)
                && StorageFormatting.fileSize(at: url) >= minimumBytes
        }
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}

struct LargeFileSafetyPolicy: Sendable {
    private let allowedExtensions: Set<String> = [
        "7z", "ace", "arj", "br", "bz2", "cab", "cb7", "cbr", "cbt", "cbz", "cpio", "cpgz",
        "deb", "dmg", "ear", "gz", "iso", "jar", "lz", "lz4", "lzh", "lzma", "pkg", "rar",
        "rpm", "sit", "sitx", "tar", "tbz", "tbz2", "tgz", "tlz", "txz", "war", "xar", "xip",
        "xz", "zip", "zipx", "zst",
        "aab", "apk", "ipa", "ipsw",
        "avi", "m4v", "mkv", "mov", "mp4", "webm",
        "heic", "jpeg", "jpg", "png", "psd", "raw", "tiff", "webp",
        "avro", "bak", "backup", "csv", "db", "db3", "dump", "h5", "hdf5", "jsonl",
        "log", "mmdb", "ndjson", "onnx", "orc", "parquet", "realm", "sql", "sqlite", "sqlite3"
    ]

    private let blockedPathComponents: Set<String> = [
        ".build", ".git", ".gradle", ".swiftpm", ".venv",
        "Applications", "Library", "System",
        "DerivedData", "Pods", "build", "node_modules", "vendor", "venv"
    ]

    func isReviewSafeCandidate(_ url: URL) -> Bool {
        let components = Set(url.standardizedFileURL.pathComponents)
        guard components.isDisjoint(with: blockedPathComponents) else { return false }
        guard !url.lastPathComponent.hasPrefix(".") else { return false }
        guard !isExecutable(url) else { return false }
        return allowedExtensions.contains(url.pathExtension.lowercased())
    }

    private func isExecutable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isExecutableKey])
        return values?.isExecutable == true
    }
}
