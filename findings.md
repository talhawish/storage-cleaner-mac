# Storage Cleaner — Codebase Audit Findings

Comprehensive audit of all screens, services, infrastructure, and tests.

Generated: June 22, 2026
Last updated: June 22, 2026 (re-audited after fixes)

Remaining issues only — fixed items removed.

---

## 🟠 Major Bugs

### M1. `FileManagerCleanupService.delete()` blocks `@MainActor` → ❌ Not fixed
**File:** `StorageCleaner/Core/Services/CleanupService.swift:44-80`

Sync `FileManager` operations including `directorySize()` enumeration on the main actor.

### M2. `LargeFilesView` / `LeftoversView` recompute `itemSize()` on every body render → ❌ Not fixed
**Files:** `LargeFilesView.swift:28-39`, `LeftoversView.swift:15-25`

`StorageFormatting.itemSize(at:)` called on main thread every render. Should cache results.

### M3. `fileSize()` returns 0 for directories in large files / leftovers → ❌ Not fixed
`StorageFormatting.fileSize(at:)` doesn't recurse into directories.

### M5. `Process` pipe read can deadlock with subprocess → ❌ Not fixed
**Files:** `DockerService.swift:323`, `CLIRemovalService.swift:361`, `ProcessExecutor.swift:62-64`

`readDataToEndOfFile()` + `waitUntilExit()` pattern can deadlock if subprocess fills 64 KB pipe buffer.

### M6. `ForEach` with `\.self` on URL arrays — crash on duplicates → ❌ Not fixed
**Files:**
- `CategoryDetailView.swift:287` — `ForEach(filteredURLs, id: \.self)`
- `CleanupDetailSheet.swift:186` — `ForEach(summary.samplePaths, id: \.self)`

### M7. `Non-Sendable` `Process` in `@Sendable` closure → ❌ Not fixed
**Files:** `DockerService.swift:309`, `CLIRemovalService.swift:338`, `ProcessExecutor.swift:46`

### M9. Trashing a Trash item fails → ❓ Needs verification
**File:** `CleanupService.swift:63-66`

### M10. Picker with invalid stored `Int` shows no selection → ❓ Needs verification
**File:** `LargeFilesView.swift`

### M11. No "no search results" empty state → ❓ Needs verification
**Files:** `CategoryDetailView.swift:39-47`, `CLIProgramsView.swift:36-43` — search results.

---

## 🟡 Functional Gaps

### G1. No deep link / URL handler → ❌ Not fixed
`StorageCleanerApp.swift` — no `onOpenURL` support.

### G2. Accessibility identifiers on InitialStateView → ❓ Needs verification

### G3. `DetailDirectoryLevel.level(for:)` blocks main thread → ❌ Not fixed
**File:** `DetailDirectoryLevel.swift:27-43` — sync `contentsOfDirectory`.

### G4. `CLIProgramsView.load()` sizes programs sequentially → ❌ Not fixed
**File:** `CLIProgramsView.swift` — for loop, not `withTaskGroup`.

### G5. `SafeToDeleteView` stores option IDs as comma-separated string → ❓ Needs verification

### G6. `StoredScan.cleanedBytes` overflows silently → ❌ Not fixed
**File:** `StoredModels.swift:13` — `Int64` with `+=` and no overflow check.

### G7. Multiple screens register ⌘R simultaneously → ❓ Needs verification

### G9. UI test references non-existent "primary-scan-button" → ❌ Not fixed
**File:** `StorageCleanerUITests.swift:12` — Still looks for "primary-scan-button" instead of "toolbar-scan-button". Test has fallback masking the bug.

### G10. GCD mixed with Swift concurrency → ❌ Not fixed
**File:** `ProcessExecutor.swift:45` — `DispatchQueue.global().async` with `withCheckedThrowingContinuation`.

---

## 🔵 Code Quality

### Q2. `SectionViewBuilders.swift` copy-paste boilerplate → ❌ Not fixed
Still 487 lines of duplicated phase-state switching per section.

### Q3. Massive test coverage gaps → ❌ Not fixed
23 of 32 features still have zero unit tests.

### Q5. `nonisolated(unsafe) static var preview` — data race risk → ❌ Not fixed
**File:** `PersistenceController.swift:7`

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
| 🟠 Major | 9 |
| 🟡 Functional Gap | 8 |
| 🔵 Code Quality | 3 |
| 💡 Feature Request | 20 |

Top items:
1. `CleanupService` main-thread blocking (M1)
2. `itemSize()` cache in LargeFiles/Leftovers (M2)
3. `readDataToEndOfFile()` deadlock risk (M5)
4. `ForEach` with `\.self` on URL arrays (M6)
5. Deep link / URL handler (G1)
