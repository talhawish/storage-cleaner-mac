import Foundation

struct CLIAppScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .cliApps
    let title = StorageFindingKind.cliApps.title
    private let scanner: PathListScanner

    init(paths: PathBuilder = PathBuilder(), collector: FileSystemCollector) {
        let homePaths: [URL] = [
            paths.home(".rustup"),
            paths.home(".volta"),
            paths.home(".nvm"),
            paths.home(".fnm"),
            paths.home("Library/Caches/Homebrew"),
            paths.home(".cargo/bin"),
            paths.home(".pyenv"),
            paths.home(".rbenv"),
            paths.home(".rvm")
        ]
        let systemPaths: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/Caskroom", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/var", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Cellar", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/Caskroom", isDirectory: true)
        ]

        scanner = PathListScanner(
            kind: .cliApps,
            domain: .cliTooling,
            paths: homePaths + systemPaths,
            safety: .review,
            collector: collector
        )
    }

    func scan() async -> CategoryScanResult {
        await scanner.scan()
    }
}
