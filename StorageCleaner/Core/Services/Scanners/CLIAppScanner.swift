import Foundation

struct CLIAppScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .cliApps
    let title = StorageFindingKind.cliApps.title
    private let scanner: PathListScanner

    init(collector: FileSystemCollector) {
        scanner = PathListScanner(
            kind: .cliApps,
            domain: .cliTooling,
            paths: DependencyPaths.CLI.homeDirs + DependencyPaths.CLI.systemDirs,
            safety: .review,
            collector: collector
        )
    }

    init(homeDirectory: URL, collector: FileSystemCollector) {
        let homeDirs = DependencyPaths.CLI.homeDirs.map { homeDir in
            let relativePath = homeDir.path.replacingOccurrences(
                of: FileManager.default.homeDirectoryForCurrentUser.path,
                with: ""
            )
            return homeDirectory.appendingPathComponent(relativePath)
        }
        scanner = PathListScanner(
            kind: .cliApps,
            domain: .cliTooling,
            paths: homeDirs + DependencyPaths.CLI.systemDirs,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
