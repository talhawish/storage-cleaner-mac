# Storage Cleaner — Codebase Audit Findings

Comprehensive audit of all screens, services, infrastructure, and tests.

Generated: June 22, 2026
Last updated: June 24, 2026 (Extended deep-dive, corrected)

Remaining issues only — fixed items removed.

---

## 🟠 Major Bugs

### M3. `fileSize()` returns 0 for directories → ❌ Not fixed (limited impact)
`StorageFormatting.fileSize(at:)` doesn't recurse into directories. Currently only called on regular files by all callers (`LargeFileScanner`, `MediaCategoryView`, `MediaGridItem`, `MediaListRow`, `MediaPreviewSheet`), so the bug is latent. `SystemJunkView` acknowledges this in a comment and uses pre-computed scanner totals instead. Fix `fileSize` to delegate to `itemSize` for directories.

### M6. `ForEach` with `\.self` on URL arrays — crash on duplicates → ❌ Not fixed
**Files:**
- `CategoryDetailView.swift:287` — `ForEach(filteredURLs, id: \.self)`
- `CleanupDetailSheet.swift:186` — `ForEach(summary.samplePaths, id: \.self)`

### M7. `Non-Sendable` `Process` in `@Sendable` closure → ❌ Not fixed
**Files:** `DockerService.swift:309`, `CLIRemovalService.swift:338`, `EmulatorManagementService.swift:224`

### M9. Trashing a Trash item fails → ❓ Needs verification
**File:** `CleanupService.swift:63-66` — `trashItem` on a URL already inside `~/.Trash` fails. `TrashStorageScanner` scans `~/.Trash` with safety `.review`, but if user proceeds, the `trashItem` call errors and the failure is silently recorded in `CleanupResult.failedURLs` — never surfaced to the user.

### M10. Picker with invalid stored `Int` shows no selection → ❓ Needs verification
**File:** `LargeFilesView.swift`

### M11. No "no search results" empty state → ❓ Needs verification
**Files:** `CategoryDetailView.swift:39-47`, `CLIProgramsView.swift:36-43` — search filtering yields empty list with no prompt.

---

### N1. `BrowserCacheScanner` defined but never registered → ❌ New
**File:** `ConcreteStorageScanners.swift:168` defines `BrowserCacheScanner`. `LiveStorageScanner.live()` (line 174-215) registers 33 scanners but never includes it. `.browserCaches` findings are **never produced** during a real scan. Browser cache paths ARE listed in `QuickClean.allPaths` (`DependencyPaths.swift:330-358`) for the QuickClean palette, but the main scan pipeline ignores them entirely.

**Fix:** Add `BrowserCacheScanner(collector: collector)` to the `LiveStorageScanner.live()` array.

### N2. `~/.gradle/caches` double-counted by two scanners → ❌ New
`DependencyPaths.Android.cacheDirs` (line 181): `home(".gradle/caches")`
`DependencyPaths.Gradle.cacheDirs` (line 92): `home(".gradle/caches")`

Both `AndroidStudioStorageScanner` (`.androidStudioArtifacts` kind) and `GradleCacheScanner` (`.gradleDependencies` kind) scan this path. Two separate `StorageFinding` objects in the dashboard each report the same bytes — the user sees the same ~/.gradle/caches counted under both Mobile Development and Other Caches.

**Fix:** Remove `home(".gradle/caches")` from `DependencyPaths.Android.cacheDirs` (it is correctly owned by `Gradle`).

### N3. Docker finding has empty `filePaths` when daemon is reachable → ❌ New
**File:** `ConcreteStorageScanners.swift:56` — When Docker daemon responds with data, `DockerStorageScanner` returns a `StorageFinding` with `filePaths: []`. The user sees Docker's total bytes in the dashboard but cannot browse individual images/containers/volumes, cannot select specific items to delete, and the finding cannot be pruned after deletion. The fallback `PathListScanner` (used when Docker is unreachable) correctly populates `filePaths` from `DependencyPaths.Docker.cacheDirs`.

Additionally, the fallback path covers `~/.colima` and `~/Library/Application Support/OrbStack` but these are **never scanned** when Docker Desktop is running and responsive (N3b).

### N4. `DashboardViewModel` stores `CLIRemovalService` but not `EmulatorManagementService` → ❌ New
**File:** `DashboardViewModel.swift:11` — `CLIRemovalService` is injected for CLI/runtime deletion history reconciliation. `EmulatorManagementService` has no counterpart — emulator deletions in `EmulatorsView` bypass the ViewModel entirely and are not recorded in scan history.

---

## 🟡 Functional Gaps

### G1. No deep link / URL handler → ❌ Not fixed
`StorageCleanerApp.swift` — no `onOpenURL` support.

### G2. Accessibility identifiers on InitialStateView → ❓ Needs verification

### G3. `DetailDirectoryLevel.level(for:)` blocks main thread → ❌ Not fixed
**File:** `DetailDirectoryLevel.swift:27-43` — sync `contentsOfDirectory` called from `pushDirectoryLevel` on `@MainActor`.

### G4. `CLIProgramsView.load()` sizes programs sequentially → ❌ Not fixed
**File:** `CLIProgramsView.swift` — for loop, not `withTaskGroup`.

### G5. `SafeToDeleteView` stores option IDs as comma-separated string → ❓ Needs verification

### G7. Multiple screens register ⌘R simultaneously → ❓ Needs verification
`DashboardView`, `SystemJunkView`, `DeveloperStorageView` all register `.keyboardShortcut("r", modifiers: [.command])`. Works in practice because SwiftUI's focused view handles it, but overlapping shortcuts can cause unexpected behavior.

### G9. UI test references non-existent "primary-scan-button" → ❌ Not fixed
**File:** `StorageCleanerUITests.swift:12` — Looks for "primary-scan-button" instead of real "toolbar-scan-button". Test has fallback masking the bug.

---

## 🔵 Code Quality

### Q2. `SectionViewBuilders.swift` copy-paste boilerplate → ❌ Not fixed
487 lines of duplicated phase-state switching per section.

### Q3. Massive test coverage gaps → ❌ Not fixed
23 of 32 features still have zero unit tests. Views (`CategoryDetailView`, `DeleteConfirmationSheet`, `FileRowView`, `MediaPreviewSheet`, `AppsView`, many QuickClean components, etc.) have no test coverage.

### Q5. `nonisolated(unsafe) static var preview` — data race risk → ❌ Not fixed
**File:** `PersistenceController.swift:7`

### Q6. `OrphanDirectoryResolver` limit hardcoded at 200 → ❌ New
**File:** `SystemJunkScanners.swift:48,86,98,101` — The `limit: 200` parameter is hardcoded and not user-configurable. Power users who have installed/uninstalled hundreds of apps may silently miss orphaned directories beyond this cap.

### Q7. External volumes preference read per-scanner at scan time → ❌ New
**File:** `ScanPreferences.swift:8` — `UserDefaults.standard.bool(forKey: "includeExternalVolumes")` is evaluated independently by each scanner (concurrent via `withTaskGroup`). Toggling the setting mid-scan could cause inconsistent behavior between scanners.

---

## 🟡 Scanners Module Deep-Dive

### System Junk
- **Orphan detection** uses `InstalledAppCatalog` which discovers `.app` bundles from `/Applications`, `/Applications/Utilities`, `~/Applications`. Combined with curated `SystemJunkPaths.appleBundleIDs`, `alwaysInstalledBundleIDs`, and `reservedSupportDirectoryNames`. Correct and thorough.
- **Crash reports** walks `~/Library/Logs/DiagnosticReports` and `CrashReporter`, matching 8 extensions (`.crash`, `.diag`, `.hang`, `.ips`, `.memory`, `.panic`, `.spin`, `.synced`). Accurate.
- **Preferences** only checks `.plist` files at top level of `~/Library/Preferences`. Correct.
- **200-entry hardcap** (Q6) applies to each orphan root independently.
- **Test coverage** is excellent — `SystemJunkScannersTests` covers all five scanners with temporary directories and stubbed catalogs.

### Developer Storage (Dependencies)
- **33 scanners** registered. All use `PathListScanner` or `FilePatternScanner` against `DependencyPaths` directories.
- **Paths are comprehensive**: npm, pnpm, yarn, bun, pip, poetry, conda, pipenv, uv, cargo, go, composer, gems, nuget, gradle, maven, ollama, huggingface, LM Studio, stable-diffusion-webui, Android SDK, Flutter, Xcode, CoreSimulator, SwiftPM, Docker, Colima, OrbStack.
- **BrowserCacheScanner exists but is never wired up** (N1).
- **`~/.gradle/caches` double-counted** (N2).
- **Docker scanner** correctly checks daemon health via `docker info`. Non-Docker runtimes (Colima, OrbStack) only scanned when daemon unreachable (N3b). When daemon responds, the finding has no `filePaths` (N3a).
- **Test coverage** good for scanners (LiveStorageScannerTests, LeftoversScannerTests, RuntimeVersionScannerTests). Features like CategoryDetailView have zero tests.

### Project Activity
- Scans 15+ root directories. `ProjectActivityScanner` is an **actor** — runs on its own executor, fully async, cancellable.
- **Hibernation** removes regenerable dependencies and optionally compresses projects to zip.
- **Modification date** tracking correctly excludes dependency files (so `npm install` doesn't make the project look "worked on").
- **Hidden files** inside projects are excluded from modification tracking (`!relativeComponents.contains(where: { $0.hasPrefix(".") })` at `ProjectActivityScanner.swift:150`) but still measured as dependency bytes. Correct.
- **Well-tested** (`ProjectActivityScannerTests`, `ProjectActivityScannerIconTests`, `ProjectActivityViewModelTests`, `ProjectCompressionServiceTests`, `ProjectHibernationServiceTests`).

### Emulators
- Apple runtimes via `xcrun simctl runtime list -j`. Android via `$ANDROID_SDK_ROOT/system-images/` with fallback to `~/Library/Android/sdk/system-images`.
- Removal: `xcrun simctl runtime delete` for Apple (re-downloadable), Trash for Android.
- `EmulatorManagementService` uses injected side effects — fully testable.
- **Not integrated** with DashboardViewModel (N4) — deletions bypass history recording.

### Permissions
- `DirectoryAccessProbe` uses `opendir()` syscall (not `FileManager.isReadableFile`) to detect TCC denials. **Correct** — `isReadableFile` lies about TCC-protected paths.
- Covers: `~`, `~/Desktop`, `~/Downloads`, `~/Movies`, `~/Pictures`, `~/Library`, `~/.Trash`. Trash is non-blocking.
- `PermissionRequiredView` shows blocked locations with deep-link to System Settings pane.
- **Well-designed** — `StoragePermissionHandling` protocol with `.live`/`.demo` variants.

### Cleanup Service
- `FileManagerCleanupService` always moves to Trash — never hard-deletes. Safe by design.
- `directorySize` properly recurses using `FileManager.enumerator`.
- `CLIRemovalService` handles Homebrew (`brew uninstall`), npm/pnpm/bun globals, with broken-symlink sweep after removal.
- All side effects injected — fully testable.

### Runtime Versions
- `RuntimeVersionCatalog` data-driven with descriptors for nvm, Volta, fnm, Bun, Deno, pyenv, rbenv, RVM, rustup, goenv, GVM, phpenv, Laravel Herd, .NET, Jabba, jEnv, SDKMAN, GHCup, Stack, FVM, asdf, mise, Homebrew versioned formulae, system JDKs.
- Comprehensive — new tools added by extending descriptor lists.

---

## 💡 Feature Suggestions (unchanged)

### F1. Space Savings Timeline / Projection
### F2. One-Click "Deep Clean" Modal
### F3. Xcode-Specific Dashboard
### F4. npm/Gradle/Rust pnpm Workspace Analyzer
### F5. Scheduled Automatic Cleanup
### F6. Export / Share Report
### F7. App Bundle / Xcode Archive Explorer
### F8. OrbStack / Colima / Lima / Podman Support
### F9. Docker Image Layer Browser
### F10. Homebrew Package Cleanup with Dependents Graph
### F11. Homebrew Bundle / Dev Setup Restore
### F12. Git Working Tree / Clone Analyzer
### F13. ML to Predict "Safe to Delete"
### F14. Per-Project "Hibernate" with Restore UI
### F15. Home Screen Widget
### F16. Menu Bar App
### F17. iCloud + Time Machine Integration
### F18. AI Model Manager Specialization
### F19. Onboarding Flow — "First Scan" Wizard
### F20. Undo / Restore from Trash Button

---

## 📊 Remaining

| Severity | Count |
|----------|-------|
| 🟠 Major | 8 (M3, M6, M7, M9, M10, M11, N1, N2) |
| 🟠 Major (Infrastructure) | 2 (N3, N4) |
| 🟡 Functional Gap | 7 (G1-G5, G7, G9) |
| 🔵 Code Quality | 5 (Q2, Q3, Q5, Q6, Q7) |
| 💡 Feature Request | 20 |

Top items:
1. **BrowserCacheScanner never registered (N1)** — Add `BrowserCacheScanner(collector: collector)` to `LiveStorageScanner.live()`. 5-minute fix.
2. **`~/.gradle/caches` double-counted (N2)** — Remove `home(".gradle/caches")` from `DependencyPaths.Android.cacheDirs`. 2-minute fix.
3. **`ForEach` with `\.self` on URL arrays (M6)** — Crash risk with duplicate URLs.
4. **Docker finding has no `filePaths` (N3)** — Empty paths when daemon is reachable; Colima/OrbStack missed.
5. **`Non-Sendable` `Process` in `@Sendable` closure (M7)** — 3 files affected.
6. **Trashing a Trash item fails silently (M9)** — Error never surfaced to user.
