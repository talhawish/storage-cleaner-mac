import Foundation

/// Single source of truth for what counts as "developer storage" and which developer domains the
/// dynamic sidebar surfaces. Both `SidebarView` (via `DashboardViewModel`) and `DeveloperStorageView`
/// read from here so the navigation and the screen can never drift apart.
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
        .aiModelCaches
    ]

    /// Developer domains surfaced as dynamic sidebar rows, in display order. CLI Tooling is
    /// intentionally excluded — it has its own dedicated "CLI Programs" section — as are runtime
    /// versions, which live in their own section too.
    static let orderedDomains: [StorageDomain] = [
        .appleDevelopment,
        .webDevelopment,
        .mobileDevelopment,
        .containers,
        .artificialIntelligence,
        .otherCaches
    ]

    /// The developer domains actually present in a scan's findings, in display order. Domains with
    /// no detected storage are omitted so the sidebar reflects reality.
    static func detected(in findings: [StorageFinding]) -> [StorageDomain] {
        let present = Set(
            findings
                .filter { kinds.contains($0.kind) && $0.bytes > 0 }
                .map(\.domain)
        )
        return orderedDomains.filter(present.contains)
    }
}
