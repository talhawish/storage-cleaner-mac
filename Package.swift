// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "StorageCleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "StorageCleaner",
            targets: ["StorageCleaner"]
        )
    ],
    targets: [
        .executableTarget(
            name: "StorageCleaner",
            path: "Sources"
        ),
        .testTarget(
            name: "StorageCleanerTests",
            dependencies: ["StorageCleaner"],
            path: "Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)
