# AGENTS.md

This is the **single source of truth** for all AI agents (Claude Code, Codex), contributors, and
developers working on Storage Cleaner for Developers. `CLAUDE.md` is a symlink to this file — edit
only this one.

It covers two things: how the codebase is built and structured (orientation), and the mandatory
engineering standards it is held to. Failure to follow the standards is considered a defect.

---

# Build & Run

`StorageCleaner.xcodeproj` is **committed** and uses Xcode **filesystem-synchronized groups**: every
file on disk under `StorageCleaner/`, `StorageCleanerTests/`, and `StorageCleanerUITests/` is added to
its target automatically. **There is no project-generation step** — add, rename, or delete a file and
it is in the build immediately (no XcodeGen, no `project.yml`). Open `StorageCleaner.xcodeproj` (or
`Package.swift`) in Xcode and press Run; both stay in sync with the filesystem as you edit.

```bash
make bootstrap   # resolve Swift packages (first-time setup)
make run         # swift run StorageCleaner
make build       # swift build
make test        # swift test  (unit tests, SwiftPM)
make ui-test     # xcodebuild UI tests
make lint        # swiftlint lint --strict --no-cache
make analyze     # xcodebuild analyze + Periphery unused-code scan
make verify      # build + test + ui-test + lint + analyze (the full CI gate)
```

Do **not** edit target membership in Xcode's UI — membership follows the folder structure. Build
settings live in the committed `project.pbxproj` (edit them in Xcode). User-specific state
(`xcuserdata`) is gitignored; the shared scheme under `xcshareddata` is committed.

Run a single unit test: `swift test --filter DashboardViewModelTests/<methodName>`.

CI (`.github/workflows/ci.yml`) runs the equivalent of `make verify` with `-warnings-as-errors`.
Treat warnings as errors locally too. SwiftLint enforces a **600-line file-length error** (warn at
600) and bans `force_unwrapping`.

## Two run modes

`AppContainer.current(arguments:)` selects dependencies from launch arguments:

* Default → `.live` (real filesystem scanners, permission checks, Trash-based cleanup).
* `--use-demo-scanner` → in-memory `DemoStorageScanner`/`DemoPermissionHandler`/`DemoCleanupService`
  for UI tests. `--complete-demo-scan-immediately` skips the simulated delay.

`AppContainer` is the **only** place concrete services are assembled. Everything downstream depends on
protocols, which is what keeps view models testable.

---

# Codebase Architecture

Layering — dependency direction is strict, Core never imports a Feature:

The app target's sources live in `StorageCleaner/` (standard Xcode app-folder layout):

* `StorageCleaner/App` — `@main` entry (`StorageCleanerApp`), `AppContainer` composition root.
* `StorageCleaner/Core` — `Models` (domain types, all typed enums), `Services` (protocols + impls),
  `Formatting`, `Persistence` (SwiftData).
* `StorageCleaner/DesignSystem` — `AppTheme` and reusable components.
* `StorageCleaner/Features/<Feature>` — MVVM screens; views do layout/bindings only, logic lives in an
  `@MainActor @Observable` view model or a Core service.

Tests live in `StorageCleanerTests/` (SwiftPM + xcodebuild) and `StorageCleanerUITests/` (xcodebuild).

## The scan pipeline (the core of the app)

1. **`StorageCategoryScanning`** — protocol for one category scanner; `scan() async -> CategoryScanResult`.
   Concrete scanners in `StorageCleaner/Core/Services/Scanners/` are thin: each declares a
   `StorageFindingKind` + `StorageDomain` + `CleanupSafety` and delegates to a reusable engine
   (`PathListScanner`, `FilePatternScanner`, `LargeFileScanner`, `DuplicateMediaScanner`, …). Target
   paths come from `DependencyPaths`; results are assembled by `CandidateFindingBuilder`.
2. **`FileSystemCollector`** — shared, read-only filesystem traversal. Uses `fileAllocatedSize`,
   honors `Task.isCancelled` throughout, caps results with `limit`, and content-hashes (SHA-256,
   streamed) only same-size files for duplicate detection.
3. **`LiveStorageScanner`** (implements `StorageScanning`) — orchestrates all category scanners
   concurrently via `withTaskGroup`, emitting `ScanEvent`s through an `AsyncStream`. Cancellation
   propagates through `continuation.onTermination`. `scanEvents(for:)` filters to a subset of kinds.
4. **`DashboardViewModel`** — consumes the stream, drives the `ScanPhase` state machine
   (`idle → scanning → results/empty/permissionRequired/failed`), and **merges** partial (per-kind)
   scan results into the existing snapshot rather than replacing it.
5. **`CleanupService`** — `FileManagerCleanupService` moves files to Trash (never hard-deletes) and
   reports `CleanupResult`. After deletion the view model recomputes affected findings in place.

## Adding a storage category

Add a `case` to `StorageFindingKind` (with `title`/`summary`), add any needed paths to
`DependencyPaths`, create a `StorageCategoryScanning` conformer that wraps an existing scanner engine,
register it in `LiveStorageScanner.live()`, and map it to a `StorageDomain` / `AppSection` as needed.
Mirror it with a test under `StorageCleanerTests/`.

## Key conventions

* **Everything is a typed enum.** `StorageFindingKind`, `StorageDomain`, `CleanupSafety`, `ScanPhase`,
  `AppSection` — no magic strings. Display metadata (titles, SF Symbols, colors) is computed on the enum.
* **Safety gating.** Every finding carries `CleanupSafety` (`.safe` vs `.review`). Media, photos,
  screenshots, loose packages, and Trash must stay `.review` (user-created risk).
* **Navigation** is a `NavigationSplitView` keyed off `SidebarItem` (`.section(AppSection)` or a
  dynamic `.developerDomain(StorageDomain)`); sections like Large Files / Screenshots scan a filtered
  subset of kinds (`AppSection.filterKinds`). The sidebar's "Developer" group renders one dynamic row
  per developer domain detected in the latest scan — derived once in `DeveloperDomains.detected(in:)`,
  the single source of truth shared with `DeveloperStorageView`.
* **Runtime versions.** `RuntimeVersionCatalog` (data-driven descriptors) detects runtimes with 2+
  installed versions — new tools are added by extending its descriptor lists. Removal reuses
  `CLIRemovalService` (`brew uninstall` for Homebrew kegs, Trash for everything else).
* **Simulators & emulators.** `EmulatorManagementService` (injected side effects, like
  `CLIRemovalService`) discovers iOS/Apple simulator runtimes via `xcrun simctl runtime list -j` and
  Android system images on disk, and removes them per platform: `xcrun simctl runtime delete`
  (re-downloadable) for Apple, Trash for Android. The screen (`Features/Emulators/`) is self-contained
  with live discovery like `AppsView`; nothing is pre-selected for removal.
* **Persistence** (`SwiftData`: `StoredScan`/`StoredFinding`/`StoredCleanupAction`) is wired via
  `PersistenceController.shared` on the `WindowGroup`.

Scanning is currently read-only inventory; the live `CleanupService` moves to Trash. See `TODO.md` and
the README's "Detection coverage" section for planned domains and the duplicate content-hash roadmap.

---

# Project Mission

Build the highest quality native macOS storage management application specifically for developers.

The application must be:

* Fast
* Reliable
* Safe
* Beautiful
* Accessible
* Highly tested
* Maintainable

Every implementation decision should prioritize correctness, performance, and user trust.

---

# Technology Stack

## Core

* Swift
* SwiftUI
* Observation Framework
* Structured Concurrency
* Actors
* Async/Await

## Architecture

* Feature-first architecture
* MVVM
* Dependency Injection
* Repository Pattern
* Service Layer
* Modular design

---

# Non-Negotiable Quality Standards

## Rule 1: Never Ship Partial Features

A feature is not complete unless:

* Implementation is complete
* Tests are written
* Documentation updated
* Accessibility reviewed
* Performance reviewed
* Static analysis passes
* Full test suite passes

---

## Rule 2: Full Regression Testing Required

After ANY change:

* Run full test suite
* Run integration tests
* Run UI tests
* Run static analysis
* Run linting

Never assume a change is isolated.

---

## Rule 3: Strict Static Analysis

Static analysis must run automatically.

Enable strict rules.

Warnings should be treated as errors whenever practical.

Required:

* SwiftLint
* Periphery
* Xcode Analyzer

No unused code.

No dead code.

No ignored warnings.

---

## Rule 4: Test Coverage

Minimum targets:

* Business Logic: 95%+
* Services: 95%+
* Scanners: 95%+
* Cleanup Engine: 95%+

Critical workflows:

* 100%

The more tests are well thought out and strict, the higher the chance of catching breaks early and the fewer bugs reach production.

---

## Rule 5: Performance First

This application processes large filesystems.

Avoid:

* Blocking main thread
* Excessive allocations
* Recursive memory-heavy traversal
* Duplicate scans

Prefer:

* Streaming
* Lazy evaluation
* AsyncSequence
* Actors
* Efficient hashing

Performance regressions are release blockers.

---

# UI Standards

## Design Philosophy

Premium macOS application.

Not a utility.

Not a dashboard.

Not a web app.

Feels native to macOS.

---

## Required UI Quality

Every screen must include:

* Loading states
* Empty states
* Error states
* Accessibility support

Empty states must be:

* Animated
* Reusable
* Beautiful
* Context-aware

---

## Animation Standards

Animations should communicate state.

Avoid decorative animation.

Requirements:

* Smooth transitions
* Interactive feedback
* Fluid navigation
* Native feel

No janky animations.

No dropped frames.

Target 120Hz capable rendering.

---

## Accessibility

Required:

* VoiceOver support
* Keyboard navigation
* Dynamic type compatibility
* High contrast support
* Reduced motion support

Accessibility bugs are production bugs.

---

# File Scanning Standards

Scanning must:

* Run in background
* Be cancelable
* Be resumable where possible
* Support progress reporting

Never freeze UI.

Never block user interaction.

---

# Safety Standards

Deletion operations are high risk.

Requirements:

* Preview before delete
* Space recovery estimate
* Confirmation step
* Restore capability when possible
* Detailed audit logs

Never permanently delete without user action.

---

# Developer Storage Domains

Support discovery and cleanup for:

## Apple Ecosystem

* DerivedData
* Archives
* Simulators
* Device Support
* SwiftPM

## Android

* SDKs
* Emulators
* Gradle

## Web

* npm
* pnpm
* yarn
* node_modules

## PHP

* Composer
* vendor

## Python

* pip
* poetry
* conda
* venv

## Rust

* cargo
* target

## Go

* module cache

## Java/Kotlin

* gradle
* maven

## .NET

* nuget
* build artifacts

## Flutter

* pub cache
* builds

## Containers

* Docker
* OrbStack
* Colima

## AI Development

* Ollama
* LM Studio
* HuggingFace
* Stable Diffusion

---

# Code Standards

Required:

* SOLID
* DRY
* KISS
* Strict typing with proper enums — prefer enums over strings or magic values for state, options, and categories
* Consistent naming, formatting, and patterns across the entire codebase
* Immutability by default — use `let` over `var`, and value types where appropriate
* **Search existing code first** — before implementing, grep/glob for reusable scanners, engines, formatters, validators, or UI components. The codebase has many shared engines (e.g., `FilePatternScanner`, `PathListScanner`, `LargeFileScanner`, `DuplicateMediaScanner`, `CandidateFindingBuilder`, `FileSystemCollector`) and DesignSystem components. Reuse them rather than reimplementing.
* **Show complete paths** — when displaying file or project locations in the UI, show the full path (or a meaningful truncated version with `...` in the middle) so users can identify the exact location. Avoid showing only the filename or last path component.

Avoid:

* Massive ViewModels
* God Objects
* Hidden dependencies
* Global mutable state
* Magic strings and magic numbers
* Inconsistent patterns or style within the same domain

---

# Component Architecture

All UI must be built from small, focused, reusable components.

## Rules

### Strict DRY (Don't Repeat Yourself)
Business logic, state checks, and utilities must be defined once and reused everywhere. Never duplicate logic across files.

**Example:** If the app needs to check `hasSubscription`, define a single computed property, method, or helper. All screens and services call that single source of truth — never reimplement the check. also app theme and colors etc

### Maximum File Length
No file may exceed 600 lines (SwiftLint fails the build at 600, warns at 600). If a file approaches this limit, extract logic into helpers, services, extensions, or subcomponents.

### Prefer Small Components
- Components should be single-purpose and reusable
- Screens compose components; they should not contain inline UI logic
- Extract repeated UI patterns into shared components

### Extract Logic
- Business logic, formatting, computation, and data transformation must live in services, helpers, or models — never in view files
- View files should contain only view layout, bindings, and simple presentation logic

### Composition over Size
- Break large screens into smaller sub-components
- Each sub-component lives in its own file
- Components are imported and composed by screens

---

# Pull Request Checklist

Before merge:

* [ ] Feature complete
* [ ] Tests added
* [ ] Accessibility reviewed
* [ ] Documentation updated
* [ ] SwiftLint passes
* [ ] Analyzer passes
* [ ] Full tests pass
* [ ] No performance regressions

---

# Definition of Done

A task is complete only if:

* Functionality works
* Tests pass
* Analyzer passes
* Lint passes
* Documentation updated
* Accessibility validated
* Performance validated

Anything less is incomplete.
