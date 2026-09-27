# Storage Cleaner — Codebase Audit Findings

Comprehensive audit of all screens, services, infrastructure, and tests.

Generated: June 22, 2026
Last updated: September 14, 2026 (sandbox and release-hardening pass)

This file is a historical audit snapshot. The September 2026 hardening pass resolved M3, M7, M10,
M11, N3, G3, G4, Q5, Q6, and Q7. The remaining entries are follow-up work or design trade-offs, not
known blockers for the sandbox resubmission.

---

## 🟠 Major Bugs

### M3. `fileSize()` returns 0 for directories → ✅ Fixed
`StorageFormatting.fileSize(at:)` now detects directories and delegates to the recursive allocated-size walker used by `itemSize(at:)`.

### M7. `Non-Sendable` `Process` in `@Sendable` closure → ✅ Fixed
CLI and emulator subprocesses now share the injectable `SystemProcessExecutor`, which owns the `Process` lifecycle and drains both output streams without putting `Process` in feature detached closures. The strict-warning build and analyzer pass.

### M10. Picker with invalid stored `Int` shows no selection → ✅ Fixed
The Large Files and Settings pickers bind through a typed `LargeFileThreshold` value and fall back to `.hundredMB` when persisted data is unknown.

### M11. No "no search results" empty state → ✅ Fixed
Category details, CLI tools, and Applications now show a reusable no-match state with a clear-search action instead of rendering a blank list.

---

### N3. Docker finding has empty `filePaths` when daemon is reachable → ✅ Resolved by design
Docker daemon resources are managed in the dedicated Docker screen, which presents resource-level actions and confirmation instead of routing daemon-reported bytes through the filesystem detail list. The filesystem fallback remains available when the daemon is unavailable.

---

## 🟡 Functional Gaps

### G1. No deep link / URL handler → ❌ Unfixed
`App/StorageCleanerApp.swift` — no `onOpenURL` support.

### G3. `DetailDirectoryLevel.level(for:)` blocks main thread → ✅ Fixed
Directory child levels are loaded asynchronously with file metadata. Row navigation uses the cached result and no longer performs synchronous enumeration on the main actor.

### G4. `CLIProgramsView.load()` sizes programs sequentially → ✅ Fixed
CLI program sizes are measured in a cancellable task group so the view does not serialize every filesystem walk.

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

### Q5. `nonisolated(unsafe) static var preview` — data race risk → ✅ Fixed
`PersistenceController.preview` is now immutable, removing the unnecessary shared mutable state and unsafe isolation escape.

### Q6. `OrphanDirectoryResolver` limit duplicated and hardcoded → ✅ Fixed
All orphan scanners use the shared `SystemJunkScanLimits.orphanDirectoryLimit` constant, currently 2,000 entries per root, so the cap is explicit and maintainable.

### Q7. External volumes preference read per-scanner at scan time → ✅ Fixed
Live scanner construction is refreshed for each scan, so scan preferences are captured consistently when scanning starts rather than only when the app container is created.

## 🟡 Scanners Module Deep-Dive

### System Junk
- **Orphan detection** uses `InstalledAppCatalog` which discovers `.app` bundles from `/Applications`, `/Applications/Utilities`, `~/Applications`. Combined with curated `SystemJunkPaths.appleBundleIDs`, `alwaysInstalledBundleIDs`, and `reservedSupportDirectoryNames`. Correct and thorough.
- **Crash reports** walks `~/Library/Logs/DiagnosticReports` and `CrashReporter`, matching 8 extensions (`.crash`, `.diag`, `.hang`, `.ips`, `.memory`, `.panic`, `.spin`, `.synced`). Accurate.
- **Preferences** only checks `.plist` files at top level of `~/Library/Preferences`. Correct.
- **Orphan cap** is centralized at 2,000 entries per root and is applied consistently.
- **Test coverage** is excellent — `SystemJunkScannersTests` covers all five scanners with temporary directories and stubbed catalogs.

### Developer Storage (Dependencies)
- **36 scanners** registered (including BrowserCacheScanner). All use `PathListScanner` or `FilePatternScanner` against `DependencyPaths` directories.
- **Paths are comprehensive**: npm, pnpm, yarn, bun, pip, poetry, conda, pipenv, uv, cargo, go, composer, gems, nuget, gradle, maven, ollama, huggingface, LM Studio, stable-diffusion-webui, Android SDK, Flutter, Xcode, SwiftPM, Docker, Colima, OrbStack. CoreSimulator cleanup is intentionally kept in the reviewed Emulators flow instead of the broad Xcode artifacts scan.
- **Docker scanner** correctly checks daemon health via `docker info`. A reachable daemon is shown in the dedicated Docker resource screen; filesystem cache paths remain the fallback when it is unavailable.
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

## 📊 Remaining follow-up work

| Severity | Count |
|----------|-------|
| 🟠 Major | 0 known release blockers |
| 🟠 Major (Infrastructure) | 0 known release blockers |
| 🟡 Functional Gap | 3 (G1, G5, G7) |
| 🔵 Code Quality | 2 (Q2, Q3) |
| 💡 Feature Request | 20 |

**Changes since last audit:**
- ✅ **G2** (Accessibility on InitialStateView) — Acceptable, removed
- ✅ **M6** (`ForEach` with `\.self` on URL arrays) — FIXED (duplicate URL rows now use positional IDs)
- ✅ **G9** (primary-scan-button identifier) — FIXED (identifier exists in WelcomeHeroSupport.swift:159)
- ✅ **N2** (`~/.gradle/caches` double-counted) — FIXED (path now owned only by Gradle)
- ✅ **N4** (emulator deletion bypassed DashboardViewModel/history) — FIXED
- ⬆️ **G7** expanded: 3 → 11 views register ⌘R
- ⬆️ **Q2** expanded: 487 → 556 lines
- ✅ **M3, M7, M10, M11, N3, G3, G4, Q5, Q6, Q7** — resolved in the September 2026 hardening pass
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

**Top follow-up items:**
1. **G1** — Add deep-link / URL handling if the product needs external navigation.
2. **Q2/Q3** — Continue extracting repeated section builders and expand view-level test coverage.
