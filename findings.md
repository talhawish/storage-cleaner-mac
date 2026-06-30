# Storage Cleaner — Codebase Audit Findings

Comprehensive audit of all screens, services, infrastructure, and tests.

Generated: June 22, 2026
Last updated: June 30, 2026 (cleanup and safety audit completed)

Remaining issues only — fixed items removed.

---

## 🟠 Major Bugs

### M3. `fileSize()` returns 0 for directories → ❌ Unfixed (latent — low impact)
`StorageFormatting.fileSize(at:)` (`Core/Formatting/StorageFormatting.swift:30`) uses `resourceValues` which doesn't recurse into directories. `itemSize(at:)` exists at line 43 and handles directories. All current callers pass regular files, so the bug is latent. Fix: delegate `fileSize` to `itemSize` for directories.

### M7. `Non-Sendable` `Process` in `@Sendable` closure → ❌ Unfixed — **EXPANDED (5+ files)**
Originally 3 files; now found in at least 5:
- `Core/Services/DockerService.swift:309` — `Process()` inside `Task.detached`
- `Core/Services/CLIRemovalService.swift:338` — `Process()` inside `Task.detached`
- `Core/Services/EmulatorManagementService.swift:399` — `Process()` inside `Task.detached`
- `Core/Services/AppBundleUninstaller.swift:62` — `Process()` inside `Task.detached`
- `Core/Services/CleanupService.swift:51` — `Task.detached` with non-Sendable `FileManager`

All create `Process` (non-Sendable) inside `@Sendable` closures. This generates compiler warnings (or will with strict concurrency). Wrap `Process` usage in a `#Sendable`-safe helper actor.

### M10. Picker with invalid stored `Int` shows no selection → ❌ Unfixed
**File:** `Features/LargeFiles/LargeFilesView.swift:11-12,172-178`
`@AppStorage("largeFileThresholdMB") private var largeFileThresholdMB` is an `Int` bound directly to a `Picker`. If the stored value doesn't match any `LargeFileThreshold` case (e.g. `200` from a future version or corruption), no tag matches and the picker shows no selection — user sees an empty segmented control. Fix: bind through a computed property that falls back to `.hundredMB`.

### M11. No "no search results" empty state → ❌ Unfixed
**Files:**
- `Features/Detail/CategoryDetailView.swift:41-49,287` — `filteredURLs` yields empty array, `ForEach` renders nothing, no prompt.
- `Features/CLIPrograms/CLIProgramsView.swift:36-47` — Same pattern.

User types a search that matches nothing and sees a blank list. Add an empty-state view.

---

### N3. Docker finding has empty `filePaths` when daemon is reachable → ❌ Unfixed
**File:** `Core/Services/Scanners/ConcreteStorageScanners.swift:48-57`
When Docker daemon responds with data, `DockerStorageScanner` returns a `StorageFinding` with `filePaths: []`. Dashboard shows Docker's total bytes but user cannot browse individual items or select them for deletion. Fallback `PathListScanner` (used when daemon unreachable) populates `filePaths` correctly. Additionally, Colima/OrbStack cache directories are never scanned when Docker Desktop is running and responsive.

---

## 🟡 Functional Gaps

### G1. No deep link / URL handler → ❌ Unfixed
`App/StorageCleanerApp.swift` — no `onOpenURL` support.

### G3. `DetailDirectoryLevel.level(for:)` blocks main thread → ❌ Unfixed
**Files:** `Features/Detail/DetailDirectoryLevel.swift:28` — `contentsOfDirectory` (sync I/O) called from `CategoryDetailView.swift:333-338` `pushDirectoryLevel(from:)` on `@MainActor`. Blocks UI during directory enumeration.

### G4. `CLIProgramsView.load()` sizes programs sequentially → ❌ Unfixed
**File:** `Features/CLIPrograms/CLIProgramsView.swift:392-399` — `for url in urls { sizes[url] = StorageFormatting.itemSize(at: url) }` in a `Task.detached` but sequential. Use `withTaskGroup` for concurrent measurement.

### G5. `SafeToDeleteView` stores option IDs as comma-separated string → ❌ Unfixed (fragile)
**File:** `Features/Settings/SafeToDeleteView.swift:352-361`
`enabledOptions` serialized as comma-joined string in `@AppStorage("enabledCleanupOptions")`. Fragile if any option ID ever contained a comma (currently none do). Acceptable for now.

### G7. Multiple screens register ⌘R simultaneously → **EXPANDED (11 views)**
Originally 3 views (DashboardView, SystemJunkView, DeveloperStorageView). Now **11 views** register `.keyboardShortcut("r", modifiers: [.command])`:
- `Features/Dashboard/DashboardView.swift:67`
- `Features/SystemJunk/SystemJunkView.swift:138`
- `Features/DeveloperStorage/DeveloperStorageView.swift:80`
- `Features/Media/MediaCategoryView.swift:124`
- `Features/Docker/DockerView.swift:76`
- `Features/LargeFiles/LargeFilesView.swift:87`
- `Features/Emulators/EmulatorsView.swift:90`
- `Features/RuntimeVersions/RuntimeVersionsView.swift:94`
- `Features/Leftovers/LeftoversView.swift:80`
- `Features/CLIPrograms/CLIProgramsView.swift:137`
- Possibly more.

Works in practice via SwiftUI's focused-view handling but increases collision risk.

---

## 🔵 Code Quality

### Q2. `SectionViewBuilders.swift` copy-paste boilerplate → **EXPANDED (556 lines)**
Originally 487 lines, now 556 lines. Still duplicate phase-state switching per section. The comment says it was extracted to keep `AppShellView` under 500 lines, but the builder itself now approaches the 600-line SwiftLint limit.

### Q3. Massive test coverage gaps → ❌ Unfixed
23 of 32 features still have zero unit tests. Views (CategoryDetailView, DeleteConfirmationSheet, FileRowView, MediaPreviewSheet, AppsView, many QuickClean components, etc.) have no test coverage.

### Q5. `nonisolated(unsafe) static var preview` — data race risk → ❌ Unfixed
**File:** `Core/Persistence/PersistenceController.swift:7`

### Q6. `OrphanDirectoryResolver` limit hardcoded at 200 → **EXPANDED (8 occurrences)**
Originally cited 4 occurrences (lines 48,86,98,101). Now hardcoded `limit: 200` at 8 locations in `Core/Services/Scanners/SystemJunkScanners.swift:263,278,299,314,336,341,359,360`. Power users with hundreds of apps silently miss orphaned directories beyond the cap.

### Q7. External volumes preference read per-scanner at scan time → ❌ Unfixed
**File:** `Core/Services/ScanPreferences.swift:7-8` — `UserDefaults.standard.bool(forKey:)` evaluated independently by each concurrent scanner. Changing the setting mid-scan could cause inconsistency.

## 🟡 Scanners Module Deep-Dive

### System Junk
- **Orphan detection** uses `InstalledAppCatalog` which discovers `.app` bundles from `/Applications`, `/Applications/Utilities`, `~/Applications`. Combined with curated `SystemJunkPaths.appleBundleIDs`, `alwaysInstalledBundleIDs`, and `reservedSupportDirectoryNames`. Correct and thorough.
- **Crash reports** walks `~/Library/Logs/DiagnosticReports` and `CrashReporter`, matching 8 extensions (`.crash`, `.diag`, `.hang`, `.ips`, `.memory`, `.panic`, `.spin`, `.synced`). Accurate.
- **Preferences** only checks `.plist` files at top level of `~/Library/Preferences`. Correct.
- **200-entry hardcap (Q6)** applies to each orphan root independently — 8 hardcoded occurrences.
- **Test coverage** is excellent — `SystemJunkScannersTests` covers all five scanners with temporary directories and stubbed catalogs.

### Developer Storage (Dependencies)
- **34 scanners** registered (including BrowserCacheScanner). All use `PathListScanner` or `FilePatternScanner` against `DependencyPaths` directories.
- **Paths are comprehensive**: npm, pnpm, yarn, bun, pip, poetry, conda, pipenv, uv, cargo, go, composer, gems, nuget, gradle, maven, ollama, huggingface, LM Studio, stable-diffusion-webui, Android SDK, Flutter, Xcode, SwiftPM, Docker, Colima, OrbStack. CoreSimulator cleanup is intentionally kept in the reviewed Emulators flow instead of the broad Xcode artifacts scan.
- **Docker scanner** correctly checks daemon health via `docker info`. Non-Docker runtimes (Colima, OrbStack) only scanned when daemon unreachable (N3b). When daemon responds, the finding has no `filePaths` (N3a).
- **Test coverage** good for scanners (LiveStorageScannerTests, LeftoversScannerTests, RuntimeVersionScannerTests). Features like CategoryDetailView have zero tests.

### Project Activity
- Scans 15+ root directories. `ProjectActivityScanner` is an **actor** — runs on its own executor, fully async, cancellable.
- **Hibernation** removes regenerable dependencies and optionally compresses projects to zip.
- **Modification date** tracking correctly excludes dependency files (so `npm install` doesn't make the project look "worked on").
- **Hidden files** inside projects are excluded from modification tracking but still measured as dependency bytes. Correct.
- **Well-tested** (ProjectActivityScannerTests, ProjectActivityScannerIconTests, ProjectActivityViewModelTests, ProjectCompressionServiceTests, ProjectHibernationServiceTests).

### Emulators
- Apple runtimes via `xcrun simctl runtime list -j`. Android via `$ANDROID_SDK_ROOT/system-images/` with fallback to `~/Library/Android/sdk/system-images`.
- Removal: `xcrun simctl runtime delete` for Apple (re-downloadable), Trash for Android.
- `EmulatorManagementService` uses injected side effects — fully testable.
- Deletion completion reconciles through `DashboardViewModel`, so path-backed emulator findings and cleanup history update immediately.

### Permissions
- `DirectoryAccessProbe` uses `opendir()` syscall (not `FileManager.isReadableFile`) to detect TCC denials. **Correct** — `isReadableFile` lies about TCC-protected paths.
- Covers: `~`, `~/Desktop`, `~/Downloads`, `~/Movies`, `~/Pictures`, `~/Library`, `~/.Trash`. Trash is non-blocking.
- `PermissionRequiredView` shows blocked locations with deep-link to System Settings pane.
- **Well-designed** — `StoragePermissionHandling` protocol with `.live`/`.demo` variants.

### Cleanup Service
- `FileManagerCleanupService` moves to Trash by default; items already in `~/.Trash` are permanently removed (emptied). Safe by design.
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
| 🟠 Major | 4 (M3, M7, M10, M11) |
| 🟠 Major (Infrastructure) | 1 (N3) |
| 🟡 Functional Gap | 5 (G1, G3, G4, G5, G7) |
| 🔵 Code Quality | 5 (Q2, Q3, Q5, Q6, Q7) |
| 💡 Feature Request | 20 |

**Changes since last audit:**
- ✅ **G2** (Accessibility on InitialStateView) — Acceptable, removed
- ✅ **M6** (`ForEach` with `\.self` on URL arrays) — FIXED (duplicate URL rows now use positional IDs)
- ✅ **G9** (primary-scan-button identifier) — FIXED (identifier exists in WelcomeHeroSupport.swift:159)
- ✅ **N2** (`~/.gradle/caches` double-counted) — FIXED (path now owned only by Gradle)
- ✅ **N4** (emulator deletion bypassed DashboardViewModel/history) — FIXED
- ⬆️ **M7** expanded: 3 → 5+ files (AppBundleUninstaller.swift, CleanupService.swift added)
- ⬆️ **G7** expanded: 3 → 11 views register ⌘R
- ⬆️ **Q2** expanded: 487 → 556 lines
- ⬆️ **Q6** expanded: 4 → 8 occurrences of hardcoded limit: 200
- ✅ **Cleanup Pipeline C1–C7** — FIXED (snapshot reconciliation, system JDK safety,
  hidden-file byte accounting, emulator history/snapshot reconciliation, zero-byte removals,
  normalized URL pruning, and per-item cleanup tasks)
- ✅ **Safety audit** — FIXED (Device Support, Cargo cache, Go module cache, orphaned
  app caches, and old crash reports are safe; CoreSimulator, Docker, AI models,
  Android/Apple emulators, global tools, media, packages, Trash, and user-state
  app data remain review-only)
- ✅ **Subscription guard: `.lifetime` default** — FIXED (`DashboardViewModel+Subscription.swift`:
  `currentEntitlement` defaults to `.free` when no controller wired, not `.lifetime`)
- ✅ **Subscription guard: EmulatorsViewModel gate** — FIXED (`EmulatorsViewModel.swift`:
  added `canDelete` closure checked in `delete()`; wired from `EmulatorsView.init`)

**Top items:**
1. **Docker finding has no `filePaths` (N3)** — Empty paths when daemon is reachable; Colima/OrbStack missed.
2. **`Non-Sendable` `Process` in `@Sendable` closure (M7)** — 5+ files affected, growing.
