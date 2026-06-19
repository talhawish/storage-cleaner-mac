import Foundation

/// Pure, value-type selection model for the Duplicates screen.
///
/// Defaults are designed for the common case: every copy *except* the recommended one is marked
/// for removal, so "Remove Selected" is immediately meaningful. The user can re-elect which copy
/// to keep per group, opt individual copies out of removal, or clear/select everything.
///
/// State is keyed by group hash and file URL so it survives the group list being refreshed after a
/// deletion (the view re-derives everything from the current groups each render).
struct DuplicateSelectionState: Equatable {
    /// Overrides the recommended keep file per group (group hash → kept URL).
    private(set) var keepOverrides: [String: URL] = [:]
    /// Removable copies the user explicitly opted *out* of removing.
    private(set) var spared: Set<URL> = []

    /// The copy to keep in a group — the user's override, or the scanner's recommendation.
    func keepURL(for group: DuplicateGroup) -> URL {
        keepOverrides[group.id] ?? group.keepURL
    }

    func isKept(_ url: URL, in group: DuplicateGroup) -> Bool {
        url == keepURL(for: group)
    }

    /// A copy is marked for removal when it is not the kept copy and not spared by the user.
    func isMarkedForRemoval(_ url: URL, in group: DuplicateGroup) -> Bool {
        !isKept(url, in: group) && !spared.contains(url)
    }

    /// Re-elects which copy to keep. The newly kept copy can never be spared/removed.
    mutating func setKeep(_ url: URL, in group: DuplicateGroup) {
        keepOverrides[group.id] = url
        spared.remove(url)
    }

    /// Toggles whether a non-kept copy is marked for removal.
    mutating func toggleRemoval(_ url: URL, in group: DuplicateGroup) {
        guard !isKept(url, in: group) else { return }
        if spared.contains(url) {
            spared.remove(url)
        } else {
            spared.insert(url)
        }
    }

    /// Marks every non-kept copy in the group for removal (clears any sparing within it).
    mutating func selectAllRemovable(in group: DuplicateGroup) {
        for url in group.files.map(\.url) where !isKept(url, in: group) {
            spared.remove(url)
        }
    }

    /// Spares every copy in the group (nothing will be removed from it).
    mutating func clearSelection(in group: DuplicateGroup) {
        for url in group.files.map(\.url) where !isKept(url, in: group) {
            spared.insert(url)
        }
    }

    func removalURLs(in group: DuplicateGroup) -> [URL] {
        group.files.map(\.url).filter { isMarkedForRemoval($0, in: group) }
    }

    func removalURLs(in groups: [DuplicateGroup]) -> [URL] {
        groups.flatMap { removalURLs(in: $0) }
    }

    func removalCount(in groups: [DuplicateGroup]) -> Int {
        removalURLs(in: groups).count
    }

    /// Total bytes freed by the current selection, using per-file sizes already known from the scan.
    func removalBytes(in groups: [DuplicateGroup]) -> Int64 {
        groups.reduce(Int64(0)) { total, group in
            let removable = removalURLs(in: group).count
            return total + group.perFileBytes * Int64(removable)
        }
    }

    /// Resets to recommended defaults: keep the suggested copy, mark the rest for removal.
    mutating func reset() {
        keepOverrides.removeAll()
        spared.removeAll()
    }
}
