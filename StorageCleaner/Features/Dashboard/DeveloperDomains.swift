import Foundation

/// Single source of truth for what counts as "developer storage" and which developer domains the
/// Developer Storage screen surfaces.
enum DeveloperDomains {
    /// Finding kinds considered developer storage, shown on the Developer Storage overview and used
    /// to derive which domains are present after a scan.
    static let kinds: [StorageFindingKind] = [
        .xcodeArtifacts,
        .dockerArtifacts,
        .flutterArtifacts,
        .androidStudioArtifacts,
        .androidPackages,
        .pythonDependencies,
        .rustDependencies,
        .goDependencies,
        .phpDependencies,
        .rubyDependencies,
        .dotnetDependencies,
        .gradleDependencies,
        .cliApps,
        .nodeDependencies,
        .aiModelCaches,
        .runtimeVersions
    ]

    /// Developer domains surfaced as in-screen filters, in display order. CLI Tooling is
    /// intentionally excluded because it has its own dedicated "CLI Programs" section.
    static let orderedDomains: [StorageDomain] = [
        .appleDevelopment,
        .webDevelopment,
        .mobileDevelopment,
        .containers,
        .artificialIntelligence,
        .otherCaches
    ]

    /// The developer domains actually present in a scan's findings, in display order. Domains with
    /// no detected storage are omitted so the screen reflects reality.
    static func detected(in findings: [StorageFinding]) -> [StorageDomain] {
        let present = Set(
            findings
                .filter { kinds.contains($0.kind) && $0.bytes > 0 }
                .map(\.domain)
        )
        return orderedDomains.filter(present.contains)
    }
}
