# Storage Cleaner for Developers

A native macOS application that helps developers understand and safely reclaim storage used by build
artifacts, package caches, simulators, containers, large videos, large photos, duplicate photos,
screenshots, loose APKs, browser caches, Trash, local AI models, and other development tools.

> The current scanner performs read-only filesystem inspection. It estimates candidate sizes and counts,
> but does not move, modify, or delete user files.

## Current foundation

- Native SwiftUI interface designed for macOS
- Feature-first MVVM architecture
- Dependency injection through `AppContainer`
- Structured-concurrency scanner interface with progress and cancellation
- Live read-only scanner orchestration with separate services for Xcode, Docker, Flutter, Android Studio,
  APK/AAB files, browser caches, packages, media, duplicates, junk files, and Trash
- Permission status service for common storage locations
- Typed detection taxonomy for developer artifacts, media, photos, screenshots, packages, browser caches, and Trash
- Per-category scanning loaders with pending, scanning, completed, and skipped states
- Overview that opens with a "where your space is going" breakdown grid (storage rolled up by domain
  with share bars), actionable tips (biggest quick win, safe-vs-review split, stale caches), and the
  detection types as compact rows grouped by domain
- Reusable design-system components
- Loading, empty, error, and populated states
- VoiceOver labels, keyboard shortcuts, reduced-motion support, and semantic controls
- Light and dark appearance through system materials and semantic colors
- Unit tests for scanner behavior and dashboard state
- SwiftLint, Periphery, Xcode Analyzer, and GitHub Actions configuration

## Requirements

| Tool | Minimum | Purpose |
| --- | --- | --- |
| macOS | 14 Sonoma | Deployment target |
| Xcode | 16.4 | Build, run, test, and analyze |
| Swift | 6.1 | Language and concurrency checks |
| Homebrew | Current | Optional developer-tool installation |
| XcodeGen | Current | Reproducible `.xcodeproj` generation |
| SwiftLint | Current | Style and correctness linting |
| Periphery | Current | Unused-code detection |

Xcode includes Swift and the macOS SDK. XcodeGen, SwiftLint, and Periphery are needed for the complete
verification pipeline.

## First-time setup

1. Clone the repository and enter it:

   ```bash
   git clone <repository-url>
   cd storage-cleaner-mac
   ```

2. Select the intended Xcode installation:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app
   xcodebuild -version
   swift --version
   ```

3. Install the analysis tools:

   ```bash
   brew install xcodegen
   brew install swiftlint
   brew install peripheryapp/periphery/periphery
   ```

4. Resolve the package and check the environment:

   ```bash
   make bootstrap
   ```

No API keys, database, code generation, environment files, or external services are currently required.

## Open and run in Xcode

1. Run `make bootstrap` to generate `StorageCleaner.xcodeproj`.
2. Launch Xcode.
3. Open `StorageCleaner.xcodeproj`.
4. Choose the **StorageCleaner** scheme and **My Mac** destination.
5. Press **⌘R**.

The generated project is intentionally ignored by Git; rerun `make generate` after changing `project.yml`.
You can also open `Package.swift` directly for source development. The app requires a minimum window size
of 920 × 640 points.

## Run from Terminal

```bash
make run
```

Equivalent Swift command:

```bash
swift run StorageCleaner
```

## Build and test

Run individual checks:

```bash
make build
make test
make ui-test
make lint
make analyze
```

Run the complete local verification pipeline:

```bash
make verify
```

Useful direct commands:

```bash
swift build -Xswiftc -warnings-as-errors
swift test --parallel
xcodegen generate
xcodebuild test -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData
swiftlint lint --strict --no-cache
xcodebuild analyze -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -quiet -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=YES INDEX_ENABLE_DATA_STORE=YES
periphery scan --strict --disable-update-check --skip-build --index-store-path .build/XcodeDerivedData/Index.noindex/DataStore
```

Before opening a pull request, all checks must pass. New business logic and services require tests; critical
cleanup and deletion workflows require complete branch coverage.

## Project structure

```text
.
├── Package.swift
├── project.yml           # Reproducible Xcode project definition
├── StorageCleaner          # App target sources (standard Xcode app-folder layout)
│   ├── App                 # Application entry point and dependency composition
│   ├── Core
│   │   ├── Formatting      # Shared, presentation-independent formatting
│   │   ├── Models          # Domain models and typed state
│   │   └── Services        # Service protocols and implementations
│   ├── DesignSystem
│   │   └── Components      # Reusable visual building blocks
│   └── Features
│       ├── Dashboard       # Dashboard MVVM feature and focused components
│       └── Settings        # Native settings scene
├── StorageCleanerTests
│   ├── Core
│   └── Features
├── StorageCleanerUITests
└── .github/workflows       # Continuous integration
```

### Dependency direction

Features depend on Core abstractions and DesignSystem components. Core never imports a feature. Concrete
services are assembled only in `AppContainer`, keeping view models testable and dependencies explicit.

### Adding a feature

1. Create `StorageCleaner/Features/<FeatureName>/`.
2. Keep views focused on layout, bindings, and presentation.
3. Put state transitions in an `@MainActor @Observable` view model.
4. Put filesystem or platform behavior behind a protocol in `Core/Services`.
5. Inject the implementation through `AppContainer`.
6. Add mirrored tests under `StorageCleanerTests/Features/<FeatureName>/`.
7. Include loading, empty, error, accessibility, keyboard, and reduced-motion behavior.

Files must remain below 600 lines. Extract reusable UI and logic before a file approaches that limit.

## Safety model

Storage cleanup is destructive by nature. Production cleanup work must preserve these invariants:

- Scanning is read-only, asynchronous, progress-reporting, and cancelable.
- A user sees an exact preview and recovery estimate before cleanup.
- Nothing is permanently deleted without explicit user confirmation.
- Trash or another recoverable mechanism is preferred where possible.
- Every cleanup produces a detailed audit record.
- Paths are validated immediately before action to prevent stale or unsafe operations.

The current app intentionally implements no deletion operation.

## Detection coverage

The live scanner currently inspects these storage candidate types:

- Xcode artifacts: DerivedData, archives, simulators, and SwiftPM checkouts
- Node dependencies: `node_modules`, npm, pnpm, and yarn caches
- Docker artifacts: Docker, OrbStack, Colima images, layers, volumes, and builder caches
- Flutter artifacts: pub cache, build folders, and generated app bundles
- Android Studio artifacts: SDK caches, emulator files, system images, Studio caches, and Gradle outputs
- Leftover mobile packages: loose APK and AAB files from Android builds or emulator exports
- Leftover installers: loose DMG, PKG, IPA, ISO, and other installer/package files left in
  Downloads, Desktop, and Documents long after the app they installed (surfaced regardless of size)
- AI model caches: Ollama, LM Studio, HuggingFace, Stable Diffusion, and generated assets
- Large videos: screen recordings, simulator captures, exports, demos, and other oversized media
- Screen recordings: macOS recordings, meeting captures, simulator demos, and tutorials
- Large photos: RAW files, oversized edited exports, design assets, and heavy image formats
- Duplicate photos: likely repeated imports, edited copies, and duplicate exports
- Duplicate videos: likely repeated recordings, captures, and exported copies
- Screenshots: desktop screenshots, simulator screenshots, and stale review captures
- Browser caches: Safari, Chrome, Edge, Firefox, Arc, code caches, and temporary profile data
- Package artifacts: Gradle, Maven, Composer, pip, Poetry, conda, Cargo, Go, NuGet, and Flutter caches
- Duplicate runtime versions: multiple installed versions of the same language runtime (Node via
  nvm/Volta/fnm, Python via pyenv, Ruby via rbenv/RVM, Rust via rustup, plus Homebrew versioned
  formulae like `php@8.1`/`php@8.2`, asdf, SDKMAN, and system JDKs) — keep the newest, reclaim the rest
- Simulators & emulators: iOS/Apple simulator runtimes (often 8+ GB each) and Android system images by
  API level — view every installed OS image with its size and remove the ones you don't need. Apple
  runtimes are removed with `xcrun simctl runtime delete` (re-downloadable); Android images move to the
  Trash (restorable)
- Junk files: temporary files, logs, crash reports, disposable archives, and old disk images
- Trash: files already moved to Trash but still occupying disk space

Production scanning must keep videos, photos, screenshots, mobile packages, and Trash in review-first mode.
These files can be user-created artifacts, so the app must show exact paths and sizes before any cleanup
workflow.

Duplicate detection is currently conservative and uses filename normalization plus file size. A content-hash
scanner should be added before offering duplicate cleanup actions.

## Accessibility and interaction

All new UI must be usable with VoiceOver and keyboard navigation, remain legible with increased contrast,
and respect **Reduce Motion**. Animation should explain state changes rather than decorate the interface.
Use semantic system colors and materials so both system appearances remain supported.

Keyboard shortcuts currently available:

- **⌘R** — start a scan
- **Return** — activate the primary scan action
- **Escape** — cancel an active scan

## Development workflow

1. Read `AGENTS.md` before changing code.
2. Create a focused branch.
3. Implement the complete vertical slice, including tests and documentation.
4. Run `make verify`.
5. Manually inspect light mode, dark mode, VoiceOver, keyboard navigation, and Reduce Motion.
6. Document performance implications for scanner or cleanup changes.

Do not commit `.build`, DerivedData, user-specific Xcode state, generated reports, or secrets.

## Troubleshooting

### Xcode cannot find the package scheme

Close Xcode, remove local package metadata, and reopen `Package.swift`:

```bash
rm -rf .swiftpm
swift package resolve
```

### Command-line tools point to the wrong Xcode

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept
```

### SwiftLint or Periphery is missing

```bash
brew install swiftlint
brew install peripheryapp/periphery/periphery
```

### Clear local build output

```bash
make clean
rm -rf ~/Library/Developer/Xcode/DerivedData/StorageCleaner-*
```

## Roadmap

See `TODO.md` for planned scanner domains and release milestones. The immediate next milestone is the
production read-only filesystem inventory engine with permission handling, streaming traversal, cancellation,
and deterministic scanner fixtures.

## License

No license has been selected yet. Treat the repository as all rights reserved until a license file is added.
