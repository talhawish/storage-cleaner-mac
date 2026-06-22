import Foundation

/// A language runtime / SDK that can have several versions installed side by side.
///
/// Each case carries its own display metadata (title, SF Symbol, accent) so the UI
/// never branches on a raw string. New runtimes are added here and referenced from a
/// `RuntimeVersionCatalog` descriptor.
enum DevRuntime: String, CaseIterable, Identifiable, Sendable {
    case node
    case python
    case ruby
    case php
    case rust
    case java
    case golang
    case kotlin
    case dotnet
    case dart
    case deno
    case bun
    case elixir
    case erlang
    case perl
    case swift
    case flutter
    case scala
    case haskell
    case lua

    var id: String { rawValue }

    var title: String {
        switch self {
        case .node: "Node.js"
        case .python: "Python"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .rust: "Rust"
        case .java: "Java / JDK"
        case .golang: "Go"
        case .kotlin: "Kotlin"
        case .dotnet: ".NET"
        case .dart: "Dart"
        case .deno: "Deno"
        case .bun: "Bun"
        case .elixir: "Elixir"
        case .erlang: "Erlang"
        case .perl: "Perl"
        case .swift: "Swift"
        case .flutter: "Flutter"
        case .scala: "Scala"
        case .haskell: "Haskell"
        case .lua: "Lua"
        }
    }

    var symbolName: String {
        switch self {
        case .node, .deno, .bun: "hexagon.fill"
        case .python, .dart, .elixir, .erlang, .perl, .swift, .scala, .haskell, .lua:
            "chevron.left.forwardslash.chevron.right"
        case .ruby: "diamond.fill"
        case .php: "curlybraces"
        case .rust: "gearshape.2.fill"
        case .java, .kotlin: "cup.and.saucer.fill"
        case .golang: "tortoise.fill"
        case .dotnet: "number.square.fill"
        case .flutter: "wind"
        }
    }

    var accentColor: StorageAccentColor {
        switch self {
        case .node: .mint
        case .python: .cyan
        case .ruby: .rose
        case .php: .violet
        case .rust: .orange
        case .java, .kotlin: .orange
        case .golang: .cyan
        case .dotnet: .violet
        case .dart: .cyan
        case .deno: .teal
        case .bun: .indigo
        case .flutter: .cyan
        case .scala: .rose
        case .haskell: .violet
        case .elixir, .erlang, .perl, .swift, .lua: .teal
        }
    }
}

/// How a runtime version was installed — determines the displayed manager name and,
/// indirectly, how it is removed (`CLIRemovalService` infers the mechanism from the URL).
enum VersionSource: String, Sendable {
    case nvm
    case volta
    case fnm
    case pyenv
    case rbenv
    case rvm
    case rustup
    case homebrew
    case sdkman
    case jvm
    case herd
    case asdf
    case goenv
    case gvm
    case dotnet
    case mise
    case jabba
    case jenv
    case phpenv
    case bun
    case denoBin
    case fvm
    case flutterSdk
    case stack
    case ghcup

    /// Friendly manager label shown under the runtime title.
    var displayName: String {
        switch self {
        case .nvm: "nvm"
        case .volta: "Volta"
        case .fnm: "fnm"
        case .pyenv: "pyenv"
        case .rbenv: "rbenv"
        case .rvm: "RVM"
        case .rustup: "rustup"
        case .homebrew: "Homebrew"
        case .sdkman: "SDKMAN"
        case .jvm: "System (/Library/Java)"
        case .herd: "Laravel Herd"
        case .asdf: "asdf"
        case .goenv: "goenv"
        case .gvm: "GVM"
        case .dotnet: ".NET SDK"
        case .mise: "mise"
        case .jabba: "Jabba"
        case .jenv: "jEnv"
        case .phpenv: "phpenv"
        case .bun: "Bun"
        case .denoBin: "Deno"
        case .fvm: "FVM"
        case .flutterSdk: "Flutter SDK"
        case .stack: "Stack"
        case .ghcup: "GHCup"
        }
    }

    /// System JDKs under `/Library/Java/JavaVirtualMachines` are root-owned and cannot be
    /// moved to the Trash without elevation, so the UI offers manual guidance instead of a
    /// remove action for these. Every other source lives under the user's home directory.
    var requiresManualRemoval: Bool { self == .jvm }
}

/// A comparable version label parsed from a directory name.
///
/// Leading integer components (after an optional `v`) are compared numerically; release
/// builds outrank pre-release builds (nightly/beta/rc/…) when the numbers tie; otherwise the
/// raw label breaks ties so ordering is always deterministic.
struct VersionKey: Comparable, Hashable, Sendable {
    let numbers: [Int]
    let isPreRelease: Bool
    let raw: String

    private static let preReleaseMarkers: Set<String> = [
        "nightly", "beta", "alpha", "rc", "dev", "preview", "snapshot", "pre", "insider", "canary"
    ]

    static func parse(_ label: String) -> VersionKey {
        let lower = label.lowercased()
        // A whole alphabetic run must equal a marker (e.g. `rc` in `3.13.0rc1`), so `rc` inside
        // `aarch64` — whose run is `aarch` — is not a false positive.
        let isPre = alphabeticRuns(in: lower).contains { preReleaseMarkers.contains($0) }

        var numbers: [Int] = []
        var started = false
        for token in lower.split(whereSeparator: { ".-_+ ".contains($0) }) {
            if let value = intValue(token) {
                numbers.append(value)
                started = true
            } else if started {
                break
            }
        }

        return VersionKey(numbers: numbers, isPreRelease: isPre, raw: label)
    }

    /// Maximal runs of consecutive letters in `text` (e.g. `0rc1` → `["rc"]`).
    private static func alphabeticRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in text {
            if character.isLetter {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    /// Parses an integer from a token, tolerating a single leading `v` (e.g. `v18`).
    private static func intValue(_ token: Substring) -> Int? {
        var digits = token
        if digits.first == "v" { digits = digits.dropFirst() }
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }

    static func < (lhs: VersionKey, rhs: VersionKey) -> Bool {
        let count = max(lhs.numbers.count, rhs.numbers.count)
        for index in 0..<count {
            let left = index < lhs.numbers.count ? lhs.numbers[index] : 0
            let right = index < rhs.numbers.count ? rhs.numbers[index] : 0
            if left != right { return left < right }
        }
        if lhs.isPreRelease != rhs.isPreRelease {
            // A release (false) sorts after a pre-release (true) → release is "greater".
            return lhs.isPreRelease
        }
        return lhs.raw.localizedStandardCompare(rhs.raw) == .orderedAscending
    }
}

/// A single installed version within a `RuntimeVersionGroup`.
struct RuntimeVersionItem: Identifiable, Hashable, Sendable {
    /// The on-disk root to remove. For Homebrew this is the keg directory under `Cellar`,
    /// which `CLIRemovalService` uninstalls via `brew`; everything else is moved to Trash.
    let url: URL
    let versionLabel: String
    let key: VersionKey
    var bytes: Int64
    var isNewest: Bool

    var id: URL { url }
}

/// A runtime that has two or more versions installed by the same manager. Only multi-version
/// groups are surfaced — a single installed version is nothing to clean up.
struct RuntimeVersionGroup: Identifiable, Sendable {
    let runtime: DevRuntime
    let source: VersionSource
    /// Sorted newest → oldest. The first element is the suggested "keep".
    let items: [RuntimeVersionItem]

    var id: String { "\(runtime.rawValue).\(source.rawValue)" }

    /// Versions other than the newest — the suggested removal set and reclaimable total.
    var olderItems: [RuntimeVersionItem] { items.filter { !$0.isNewest } }

    var reclaimableBytes: Int64 { olderItems.reduce(0) { $0 + $1.bytes } }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}
