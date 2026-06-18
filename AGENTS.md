# AGENTS.md

This document defines mandatory engineering standards for all AI agents, contributors, and developers working on Storage Cleaner for Developers.

Failure to follow these rules is considered a defect.

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
No file may exceed 600 lines. If a file approaches this limit, extract logic into helpers, services, extensions, or subcomponents.

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
