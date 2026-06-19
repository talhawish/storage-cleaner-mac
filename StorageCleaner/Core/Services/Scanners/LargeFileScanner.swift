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
        return true
    }

    private func isExecutable(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isExecutableKey])
        return values?.isExecutable == true
    }
}
