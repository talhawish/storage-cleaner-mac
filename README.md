# Storage Cleaner for Developers

A native macOS application that helps developers understand and safely reclaim storage used by build
artifacts, package caches, simulators, containers, large videos, large photos, duplicate photos, duplicate documents,
screenshots, loose APKs, browser caches, Trash, local AI models, and other development tools.

> Scanning performs read-only filesystem inspection. Cleanup is a separate, explicit workflow: selected
> items are confirmed and moved to the macOS Trash so they remain recoverable.

## Current foundation

- Native SwiftUI interface designed for macOS
- Feature-first MVVM architecture
- Dependency injection through `AppContainer`
- Structured-concurrency scanner interface with progress and cancellation
- Live read-only scanner orchestration with separate services for Xcode, Docker, Flutter, Android Studio,
  APK/AAB files, browser caches, packages, media, duplicates, junk files, and Trash
- Permission status service for common storage locations
- Disk-capacity reporting aligned with macOS System Settings by using the system's important-usage estimate
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
| SwiftLint | Current | Style and correctness linting |
| Periphery | Current | Unused-code detection |

Xcode includes Swift and the macOS SDK. SwiftLint and Periphery are needed for the complete verification
pipeline.

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
   brew install swiftlint
   brew install peripheryapp/periphery/periphery
   ```

4. Resolve the package and check the environment:

   ```bash
   make bootstrap
   ```

No API keys, database, code generation, or external services are currently required.

## Open and run in Xcode

1. Run `make bootstrap` to resolve Swift packages.
2. Launch Xcode.
3. Open `StorageCleaner.xcodeproj`.
4. Choose the **StorageCleaner** scheme and **My Mac** destination.
5. Press **⌘R**.

The committed project uses filesystem-synchronized groups, so files under the app and test folders are
picked up automatically. You can also open `Package.swift` directly for source development. The app
requires a minimum window size of 920 × 640 points.

## macOS sandbox permissions

The app is sandboxed and requests access only when a feature needs it. The first scan asks you to choose
your Home folder. The Applications screen separately asks you to choose `/Applications`; that bookmark
is reused for app inventory and app-bundle moves to Trash. The app does not use Apple Events, AppleScript,
or automation of Finder. macOS may also ask for Files & Folders consent when a scan first reaches a
protected location such as Documents; Home-folder access and that system consent are separate grants.

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
xcodebuild test -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData
swiftlint lint --strict --no-cache
xcodebuild analyze -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO
xcodebuild build -quiet -project StorageCleaner.xcodeproj -scheme StorageCleaner -destination 'platform=macOS' -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=YES INDEX_ENABLE_DATA_STORE=YES
periphery scan --strict --disable-update-check --skip-build --index-store-path .build/XcodeDerivedData/Index.noindex/DataStore
```

Before opening a pull request, all checks must pass. New business logic and services require tests; critical
cleanup and deletion workflows require complete branch coverage.

## Distribution

Build a signed, notarized `.app` for sharing with other developers.

### Quick build

Ensure `.env` has the app-specific password (see below), then run:

```bash
./build.sh
```

Output: `~/Desktop/StorageCleaner.dmg` — open it and drag the app to `/Applications`.

### Manual build

### Prerequisites

- Apple Developer Program account
- [Developer ID Application](https://developer.apple.com/account) certificate installed in your Keychain

### One-time credential setup

Create an [app-specific password](https://appleid.apple.com) named `StorageCleaner Notarization`,
add it to `.env`:

```env
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

Then store it for `notarytool` (uses the password from `.env`):

```bash
source .env && xcrun notarytool store-credentials "StorageCleaner" \
  --apple-id "muhammadrizwan5040@gmail.com" \
  --team-id "848R6Y8374" \
  --password "$APP_SPECIFIC_PASSWORD"
```

### Archive, notarize, and staple

```bash
# 1. Archive with Developer ID signing
xcodebuild archive -project StorageCleaner.xcodeproj \
  -scheme StorageCleaner -configuration Release \
  -archivePath ~/Desktop/StorageCleaner.xcarchive \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=848R6Y8374

# 2. Export the signed app
cat > /tmp/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>848R6Y8374</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath ~/Desktop/StorageCleaner.xcarchive \
  -exportPath ~/Desktop/StorageCleaner-Exported \
  -exportOptionsPlist /tmp/ExportOptions.plist

# 3. Create a zip for notarization
ditto -c -k --sequesterRsrc --keepParent \
  ~/Desktop/StorageCleaner-Exported/StorageCleaner.app \
  ~/Desktop/StorageCleaner.zip

# 4. Submit to Apple's notary service
xcrun notarytool submit ~/Desktop/StorageCleaner.zip \
  --keychain-profile "StorageCleaner" \
  --wait

# 5. Staple the ticket to the app
xcrun stapler staple ~/Desktop/StorageCleaner-Exported/StorageCleaner.app

# 6. Re-zip the stapled app (the final distributable)
ditto -c -k --sequesterRsrc --keepParent \
  ~/Desktop/StorageCleaner-Exported/StorageCleaner.app \
  ~/Desktop/StorageCleaner-Notarized.zip
```

The final `StorageCleaner-Notarized.zip` opens normally on any Mac without Gatekeeper warnings.
Share it with your friend — they just unzip and drag to `/Applications`.

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

Cleanup is always user-initiated and confirmed. Filesystem-backed items move to the Trash whenever
possible; tool-managed resources such as Docker images, containers, volumes, build cache, and Apple
simulator runtimes use their owning CLI and are explicitly labeled when removal is permanent. Every
successful cleanup is written to Cleanup History. File cleanup confirmations use an immutable,
non-empty selection snapshot and preview the exact names, full paths, item count, and estimated size
before the action begins.
CLI tool and runtime version confirmations keep that snapshot while removal runs. The sheet closes
when removal starts, the list shows progress, successful entries disappear after a fresh inventory,
and failed entries remain available with a retry prompt. Package-managed tools use their package
manager for uninstall; standalone binaries and other runtime versions move to the Trash.
If Homebrew is unavailable, its formula or cask stays installed and the app reports the failure.
Global Node packages also stay installed when their matching package manager is unavailable;
trashing a package folder alone can leave manager records or links behind. CLI confirmations show
the removal method and full path for each selected item. A standalone executable removal moves
only that file to Trash, so settings and saved data elsewhere remain. A selected directory moves
with all of its contents. Homebrew uninstall does not request `--zap`; any optional cleanup of
settings and saved data requires a separate, explicit review. System JDKs require manual removal
and cannot be confirmed for automatic cleanup.
Standalone CLI tools, Android system images, Device Support packs, and project hibernation and
compression use the same Finder-style Trash operation as ordinary file cleanup. A move is recorded
as successful only when macOS returns the item's Trash destination. Failure prompts describe the
actual operation and error; they do not assume every failure is a Full Disk Access problem.
Cleanup History keeps one latest overall scan snapshot for context and lists only real cleanup
actions below it; newer full scans replace older scan-only records so routine scanning does not
fill the audit trail with "No cleanup" entries.

## Detection coverage

The live scanner currently inspects these storage candidate types:

- Project Activity: project totals use allocated on-disk bytes (including hidden repository data),
  while hibernatable space counts only regenerable dependency/build directories. Scan, hibernate,
  and compress share the same dependency inventory rules across Swift, Flutter, React Native,
  Android, Node.js, PHP, Python, Ruby, Rust, Go, Java/Kotlin, and .NET. Each technology row opens a
  detail view with project, activity, dependency, hibernation, and layered framework information.
  Detection includes React/Next.js, Vue/Nuxt/Quasar, Angular, Svelte/SvelteKit, Express, NestJS,
  Laravel, Symfony, WordPress, Django, Flask, FastAPI, Rails, Sinatra, Spring Boot, Ktor, ASP.NET Core,
  Blazor, Vapor, and common Rust and Go web frameworks. Layered frameworks are shown together without
  double-counting project storage. Discovery searches accessible Home folders at any depth, including
  hidden project directories and small projects, while pruning known dependency, cache, and VCS trees.
  Monorepos remain one storage-owning root while nested-project
  discovery identifies apps and packages inside workspace containers, counts their frameworks, and adds
  their technologies to dependency sizing and hibernation rules. Those rules are scoped to the nearest
  project boundary, preventing generic names such as `vendor`, `build`, or `dist` from affecting a sibling;
  a single polyglot component can safely contribute multiple manifest technologies at the same boundary.
  For example, a Laravel project with both `composer.json` and `package.json` can reclaim Composer's
  `vendor` and Node's `node_modules` together while keeping source files. Project hibernation and
  compression reacquire Home Folder access for the full operation in sandboxed builds; if access
  has been revoked, the confirmation shows the access error before moving any files.
- Xcode artifacts: DerivedData, archives, simulators, and SwiftPM checkouts
- Node dependencies: `node_modules`, npm, pnpm, and yarn caches
- Docker artifacts: the Docker screen queries the active Docker context for images, containers,
  volumes, live stats, canonical daemon disk usage, and reclaimable build cache. Per-resource removal
  uses the Docker CLI after an exact confirmation preview; permanent volume removal is called out
  explicitly. The dashboard reports Docker's reclaimable bytes rather than double-counting shared
  image layers. OrbStack and Colima backing stores remain read-only scan coverage.
- Flutter artifacts: pub cache, build folders, and generated app bundles
- Android Studio artifacts: SDK caches, emulator files, system images, Studio caches, and Gradle outputs
- Leftover mobile packages: loose APK and AAB files from Android builds or emulator exports
- Leftover installers: loose DMG, PKG, IPA, ISO, and other installer/package files left in
  Downloads, Desktop, and Documents long after the app they installed (surfaced regardless of size)
- AI model stores: Ollama, LM Studio's model directories, Stable Diffusion model directories,
  and Hugging Face `models--*` repositories. Hugging Face datasets/credentials and LM Studio's
  general application data are not offered as models. Quick Clean uses the same restricted paths.
- Local AI models: large weight files discovered by format across Home (including hidden folders),
  such as GGUF, GGML, SafeTensors, ONNX, TFLite, PyTorch, Core ML, and large binary weights.
  Ambiguous protobuf and binary files only qualify when their path also identifies models, weights,
  or checkpoints. Format and path matching identify candidates, not proof that an app can regenerate them.
  Known cache, SDK, simulator, runtime, Trash, and app-bundle trees are pruned; standalone models
  outside Home remain eligible for Large Files when external-volume scanning is enabled.
  Model stores and individual model files always require review before moving them to Trash.
- Other large folders: directories over 1 GiB in Home that are not already covered by focused storage
  scanners. Discovery is location-agnostic and includes hidden directories; every result is marked
  “Review first” because unfamiliar folders may contain active app or user data. Broad media/project
  locations and managed Library locations are excluded from this fallback inventory; it is not a
  complete disk-usage map. Unreadable subtrees prevent their ancestors from being offered with a
  misleading partial size. Results are largest first, and opening a row scopes the preview to that path.
  The folder and model categories share one cancellable walk per scan; separate scans own separate caches.
- Large files: any oversized file in Desktop, Downloads, Documents, Pictures, and Movies regardless of
  type — documents (PDF, DOCX, CSV, spreadsheets, slides), datasets, archives, disk images, and more.
  The scanner collects from a 10 MB floor; a single configurable threshold (shared between Settings and
  the Large Files screen, default 100 MB) filters which sizes are shown, and the largest files are always
  retained when results are capped
- Large videos: screen recordings, simulator captures, exports, demos, and other oversized media
- Screen recordings: macOS recordings, meeting captures, simulator demos, and tutorials
- Large photos: RAW files, oversized edited exports, design assets, and heavy image formats
- Duplicate photos: likely repeated imports, edited copies, and duplicate exports
- Duplicate videos: likely repeated recordings, captures, and exported copies
- Duplicate documents: byte-identical PDFs, spreadsheets (CSV/XLSX/Numbers), presentations,
  vector exports (SVG), e-books, and compressed archives (ZIP, TAR, 7z, RAR) across Documents,
  Downloads, and Desktop
- Screenshots: desktop screenshots, simulator screenshots, and stale review captures
- Browser caches: Safari, Chrome, Edge, Firefox, Arc, code caches, and temporary profile data
- Package artifacts: Gradle, Maven, Composer caches and project `vendor` folders, pip, Poetry,
  conda, Cargo, Go, NuGet, and Flutter caches
- Duplicate runtime versions: multiple installed versions of the same language runtime (Node via
  nvm/Volta/fnm/Bun, Python via pyenv, Ruby via rbenv/RVM, Rust via rustup, Go via goenv/GVM, PHP via
  phpenv/Laravel Herd, .NET, Java via Jabba/jEnv/SDKMAN/asdf, Haskell via GHCup/Stack, Flutter via
  FVM or hand-cloned SDKs, Deno, plus Homebrew versioned formulae like `php@8.1`/`php@8.2`, asdf
  plugins, and system JDKs) — keep the newest, reclaim the rest. Lives inside Developer Storage.
- Simulators & emulators: Apple simulator runtimes and device instances, iOS Device Support debug
  symbols, and Android system images — view every installed item with its size and remove the ones you
  don't need. Apple-managed resources use `simctl`; filesystem-backed items are moved to Trash while
  home-folder access remains active. Partial failures stay selected and report their removal error so
  they can be retried safely.
- Applications: app bundles are moved to Trash through security-scoped Applications access. Bundles
  that require additional authorization use AppKit's `NSWorkspace.recycle` operation, which keeps
  the item recoverable in Trash without Apple Events automation. If macOS still requires an
  administrator, the app directs the user to complete that move in Finder.
- Junk files: temporary files, logs, crash reports, disposable archives, and old disk images
- System Junk: browser caches, eligible orphaned Application Support data, caches, preferences,
  saved application state, and crash reports older than 30 days. General temporary files from
  Downloads and Desktop stay in Junk Files. Protected app-container and macOS-managed state is not
  offered as a cleanup candidate. Trash moves report per-item progress, and only successful moves
  are reconciled from the scan results.
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

Modal headers and their dismissal controls remain pinned while long modal content scrolls beneath them.
The subscription paywall caps its preferred height for smaller Mac displays, wraps feature metadata, scales
localized StoreKit prices without truncating them, and keeps purchase terms reachable in one scroll region.
Its Terms of Use and Privacy Policy are native links, and the same links remain available from Settings even
when StoreKit products are unavailable. The Terms link uses Apple's Standard EULA; App Store Connect metadata
must use the identical URL.
UI tests can add `--use-demo-free-subscription` alongside `--use-demo-scanner` to exercise Pro gating;
`--show-demo-paywall` opens that sheet immediately for focused layout and accessibility checks.
`make ui-test` keeps its runner and DerivedData under `/private/tmp` by default so macOS does not
mistake automation infrastructure for a request to access Desktop, Documents, or Downloads. Set
`UI_TEST_DERIVED_DATA` to override that location, but keep it outside privacy-protected user folders.
Demo/UI-test launches also inject an isolated in-memory emulator service, so opening Simulators & Emulators never
probes, sizes, or mutates the developer machine's real Xcode and Android installations.

Large filesystem walks drain Foundation autoreleased objects per item and remain cancellation-aware.
Media thumbnails are downsampled to their display size and share a 128 MB / 512-item cache; subprocess
stdout and stderr capture is capped at 8 MB per stream. These bounds keep repeated scans and long media
grids responsive under memory pressure without changing reported storage totals.

Keyboard shortcuts currently available:

- **⌘R** — start a scan
- **Return** — activate the primary scan action
- **Escape** — cancel an active scan

Developer Storage only presents results after all developer-storage categories have been scanned.
Results from overlapping targeted scans, such as simulator or Docker scans, remain available in their
dedicated sections but do not replace Developer Storage's initial full-scan prompt.
Its targeted scan covers toolchains and developer caches; loose APK/AAB installers are scanned
under Leftovers so opening Developer Storage does not access Desktop, Downloads, or Documents.

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

See `TODO.md` for planned scanner domains and release milestones. The current scanner provides
permission-aware, streaming, cancelable inventory with deterministic fixtures; future work is tracked in
`TODO.md`.

## Landing page

The landing page is a Nuxt 4 static site (SSG, pre-rendered HTML for SEO) in `landing/`.

### Setup

```bash
cd landing
npm install
```

### Development

```bash
cd landing
npm run dev        # local dev server
```

### Build

```bash
cd landing
npm run build      # outputs pre-rendered static site to .output/public/
```

### Deploy to Firebase

The project is configured for Firebase Hosting (`storage-cleaner-a0c0f`).

Prerequisites: [Firebase CLI](https://firebase.google.com/docs/cli) installed and logged in.

```bash
cd landing && npm run build  # build first
firebase deploy --only hosting
```

## License

No license has been selected yet. Treat the repository as all rights reserved until a license file is added.
