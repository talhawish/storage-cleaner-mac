enum DemoScanFixture {
    static let findings: [StorageFinding] = [
        StorageFinding(
            kind: .xcodeArtifacts,
            domain: .appleDevelopment,
            bytes: 32_480_000_000,
            itemCount: 138_420,
            safety: .safe,
            examples: ["DerivedData", "CoreSimulator caches", "SwiftPM checkouts"]
        ),
        StorageFinding(
            kind: .nodeDependencies,
            domain: .webDevelopment,
            bytes: 18_760_000_000,
            itemCount: 284_109,
            safety: .review,
            examples: ["node_modules", "pnpm store", "yarn cache"]
        ),
        StorageFinding(
            kind: .dockerArtifacts,
            domain: .containers,
            bytes: 14_240_000_000,
            itemCount: 82,
            safety: .review,
            examples: ["Docker layers", "OrbStack images", "Colima volumes"]
        ),
        StorageFinding(
            kind: .flutterArtifacts,
            domain: .mobileDevelopment,
            bytes: 3_420_000_000,
            itemCount: 7_804,
            safety: .review,
            examples: ["pub cache", "Flutter build folders", "Generated app bundles"]
        ),
        StorageFinding(
            kind: .androidStudioArtifacts,
            domain: .mobileDevelopment,
            bytes: 12_100_000_000,
            itemCount: 32_940,
            safety: .review,
            examples: ["Android SDK", "Emulator images", "Studio caches"]
        ),
        StorageFinding(
            kind: .androidPackages,
            domain: .mobileDevelopment,
            bytes: 6_420_000_000,
            itemCount: 147,
            safety: .review,
            examples: ["Loose .apk files", "Release .aab files", "Old emulator exports"]
        ),
        StorageFinding(
            kind: .aiModelCaches,
            domain: .artificialIntelligence,
            bytes: 7_480_000_000,
            itemCount: 21,
            safety: .review,
            examples: ["HuggingFace cache", "Ollama blobs", "Stable Diffusion outputs"]
        ),
        StorageFinding(
            kind: .largeVideos,
            domain: .media,
            bytes: 18_320_000_000,
            itemCount: 11,
            safety: .review,
            examples: ["Large .mov files", "4K video exports", "Exported demos"]
        ),
        StorageFinding(
            kind: .screenRecordings,
            domain: .media,
            bytes: 9_140_000_000,
            itemCount: 27,
            safety: .review,
            examples: ["macOS recordings", "Meeting captures", "Simulator demos"]
        ),
        StorageFinding(
            kind: .largePhotos,
            domain: .photos,
            bytes: 7_220_000_000,
            itemCount: 64,
            safety: .review,
            examples: ["RAW photos", "Large PNG exports", "Design assets"]
        ),
        StorageFinding(
            kind: .duplicatePhotos,
            domain: .photos,
            bytes: 4_880_000_000,
            itemCount: 312,
            safety: .review,
            examples: ["Repeated imports", "Edited copies", "Export duplicates"]
        ),
        StorageFinding(
            kind: .duplicateVideos,
            domain: .media,
            bytes: 6_480_000_000,
            itemCount: 9,
            safety: .review,
            examples: ["Repeated recordings", "Export copies", "Duplicate demos"]
        ),
        StorageFinding(
            kind: .screenshots,
            domain: .screenshots,
            bytes: 2_760_000_000,
            itemCount: 1_184,
            safety: .review,
            examples: ["Desktop screenshots", "Simulator shots", "Review captures"]
        ),
        StorageFinding(
            kind: .browserCaches,
            domain: .browserData,
            bytes: 5_980_000_000,
            itemCount: 96_540,
            safety: .safe,
            examples: ["Safari cache", "Chrome code cache", "Firefox profiles"]
        ),
        StorageFinding(
            kind: .packageArtifacts,
            domain: .otherCaches,
            bytes: 11_360_000_000,
            itemCount: 73_240,
            safety: .review,
            examples: ["Gradle modules", "pip wheels", "Cargo registry"]
        ),
        StorageFinding(
            kind: .junkFiles,
            domain: .otherCaches,
            bytes: 1_920_000_000,
            itemCount: 474,
            safety: .review,
            examples: ["Temporary files", "Crash logs", "Old disk images"]
        ),
        StorageFinding(
            kind: .cliApps,
            domain: .cliTooling,
            bytes: 9_180_000_000,
            itemCount: 247,
            safety: .review,
            examples: [
                "Homebrew Cellar & Caskroom",
                "Homebrew download cache",
                "Rust toolchains",
                "Node version managers",
                "pyenv Python versions"
            ]
        ),
        StorageFinding(
            kind: .trash,
            domain: .trash,
            bytes: 8_940_000_000,
            itemCount: 326,
            safety: .review,
            examples: ["Deleted archives", "Old installers", "Discarded exports"]
        )
    ]
}
