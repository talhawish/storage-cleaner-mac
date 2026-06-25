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
            path: "StorageCleaner",
            exclude: [
                "Assets.xcassets",
                "StorageCleaner.entitlements",
                "Resources/StorageCleanerPro.storekit"
            ]
        ),
        .testTarget(
            name: "StorageCleanerTests",
            dependencies: ["StorageCleaner"],
            path: "StorageCleanerTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
