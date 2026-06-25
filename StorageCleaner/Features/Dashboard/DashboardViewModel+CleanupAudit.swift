import Foundation

/// Standalone helper that turns the URLs reclaimed by a `CleanupService` into
/// the `CleanupAuditEntry` values that the `ScanHistoryStore` persists. Lives
/// in its own file so the main `DashboardViewModel` body stays under the
/// 600-line type-body cap (SwiftLint's `file_length` rule).
///
/// Attribution rules, in order:
/// 1. If a dashboard finding already covers the URL (via
///    `StorageFinding.contains(_:)`), use the finding's `kind`.
/// 2. Otherwise, look up the URL against the `CleanupOptionsRegistry`'s
///    registered paths and use the matching option's `storageKind`. This is
///    the path that lets Quick Clean cleanups — including those run before
///    any scan — leave a correctly-attributed audit record.
/// 3. As a last resort, attribute the URL to `.junkFiles` so the action has
///    a permanent home in history rather than disappearing silently.
@MainActor
enum CleanupAuditRecorder {
    static func record(
        reclaimedBytesByURL: [URL: Int64],
        snapshot: ScanSnapshot?,
        historyStore: (any ScanHistoryStore)?,
        disk: ScanDiskSnapshot
    ) {
        guard let historyStore, !reclaimedBytesByURL.isEmpty else { return }

        var attributedBytes: [StorageFindingKind: Int64] = [:]
        var attributedURLs: [StorageFindingKind: [URL]] = [:]

        for (url, bytes) in reclaimedBytesByURL {
            let kind = Self.kind(
                for: url,
                snapshot: snapshot
            )
            attributedBytes[kind, default: 0] += bytes
            attributedURLs[kind, default: []].append(url)
        }

        let entries = attributedBytes.keys
            .sorted { $0.rawValue < $1.rawValue }
            .map { kind in
                CleanupAuditEntry(
                    kind: kind,
                    bytesReclaimed: attributedBytes[kind, default: 0],
                    itemCount: attributedURLs[kind, default: []].count,
                    samplePaths: Self.samplePaths(from: attributedURLs[kind, default: []])
                )
            }
        historyStore.recordCleanupActions(entries, disk: disk)
    }

    private static let samplePathLimit = 5

    /// Truncates a sequence of URLs to the first `samplePathLimit` items.
    /// Shared by every audit-emitting call site in `DashboardViewModel` so
    /// they all surface a consistent "what was deleted" preview in Cleanup
    /// History.
    static func samplePaths<S: Sequence>(from paths: S) -> [URL] where S.Element == URL {
        Array(paths.prefix(samplePathLimit))
    }

    private static func kind(for url: URL, snapshot: ScanSnapshot?) -> StorageFindingKind {
        if let finding = snapshot?.findings.first(where: { $0.contains(url) }) {
            return finding.kind
        }
        if let optionKind = CleanupOptionsRegistry.storageKind(forURL: url) {
            return optionKind
        }
        return .junkFiles
    }
}

// MARK: - Path matching

extension StorageFinding {
    /// True when the finding accounts for `url` — either via exact match or
    /// because `url` is a descendant of one of the finding's tracked URLs.
    /// Used by cleanup attribution to map a deleted URL back to the
    /// dashboard finding (or the parent finding for a child path).
    func contains(_ url: URL) -> Bool {
        trackedURLs.contains { scannedURL in
            scannedURL == url || scannedURL.isAncestor(of: url)
        }
    }
}

extension URL {
    /// True when this URL is an ancestor of `descendant` on the filesystem.
    /// Distinguishes genuine parent paths from coincidental string prefixes
    /// (e.g. "Chrome" must not claim "ChromeX") by requiring a `/`
    /// separator between the two path components.
    func isAncestor(of descendant: URL) -> Bool {
        let ancestorPath = standardizedFileURL.path
        let descendantPath = descendant.standardizedFileURL.path
        guard descendantPath.hasPrefix(ancestorPath) else { return false }
        let remainder = descendantPath.dropFirst(ancestorPath.count)
        return remainder.first == "/"
    }
}
