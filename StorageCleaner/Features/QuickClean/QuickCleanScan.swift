import SwiftUI

/// One file or directory that Quick Clean discovered. The `id` is the canonical
/// file URL so the same path can never appear twice in a single scan result,
/// even if two `CleanupOption`s share overlapping roots.
struct QuickCleanItem: Identifiable, Hashable, Sendable {
    let url: URL
    let bytes: Int64

    var id: URL { url }

    var isDirectory: Bool { url.hasDirectoryPath }
    var displayName: String { url.lastPathComponent }
}

/// One enabled `CleanupOption` and everything Quick Clean found under its
/// paths. The `id` is the option's stable identifier (e.g. `"xcode-derived"`),
/// so each category is unique even when many options belong to the same
/// `StorageDomain` or render with the same `StorageFindingKind`.
///
/// Using a dedicated value type — instead of reusing `StorageFinding` — keeps
/// the per-scan identity model simple: a category has its own toggles, its own
/// byte total, and its own item list, none of which have to be reconciled with
/// the dashboard's findings.
struct QuickCleanCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let summary: String
    let icon: String
    let tint: Color
    let domain: StorageDomain
    let safety: CleanupSafety
    let items: [QuickCleanItem]

    var bytes: Int64 {
        items.reduce(Int64(0)) { $0 + $1.bytes }
    }

    var itemCount: Int { items.count }

    var isEmpty: Bool { items.isEmpty }
}

/// The full set of categories produced by one Quick Clean scan. Provides the
/// computed totals that the header and review footer render.
struct QuickCleanScan: Hashable, Sendable {
    let categories: [QuickCleanCategory]
    /// `true` when the scan ran on a sandboxed build but the user hadn't
    /// granted home folder access. The view surfaces this as an "Access
    /// required" state instead of an empty (and misleadingly clean) review
    /// list, because the underlying measurement would have returned `0 KB`
    /// for every path.
    let accessDenied: Bool

    init(categories: [QuickCleanCategory], accessDenied: Bool = false) {
        self.categories = categories
        self.accessDenied = accessDenied
    }

    var allItems: [QuickCleanItem] {
        categories.flatMap(\.items)
    }

    var totalBytes: Int64 {
        categories.reduce(Int64(0)) { $0 + $1.bytes }
    }

    var totalItemCount: Int {
        categories.reduce(0) { $0 + $1.itemCount }
    }

    var isEmpty: Bool { categories.allSatisfy(\.isEmpty) }

    /// Categories that actually have something to clean, in display order.
    /// Categories with zero items are kept out of the review list but stay in
    /// the scan so the "scanned N categories" copy stays accurate.
    var populatedCategories: [QuickCleanCategory] {
        categories.filter { !$0.isEmpty }
    }
}

extension QuickCleanScan {
    /// The set of items the user has selected across every category. `URL` is
    /// the identity, so deselecting one item in one category cannot leak into
    /// another category that happens to share the same path.
    func selectedItems(in selection: Set<URL>) -> [QuickCleanItem] {
        allItems.filter { selection.contains($0.url) }
    }

    func selectedBytes(in selection: Set<URL>) -> Int64 {
        selectedItems(in: selection).reduce(Int64(0)) { $0 + $1.bytes }
    }
}

extension QuickCleanCategory {
    /// Returns the category with its `items` reduced to the URLs the user
    /// has selected. Used by the delete confirmation sheet so it only lists
    /// what is about to be removed.
    func selectedItems(in selection: Set<URL>) -> [QuickCleanItem] {
        items.filter { selection.contains($0.url) }
    }
}

/// One category from a completed Quick Clean run, carrying the bytes and
/// items that were *actually* moved to Trash. Distinct from `QuickCleanCategory`
/// (which holds the *scanned* state) so the success view can show the real
/// reclaimed total even when a sub-path failed to delete or the on-disk size
/// drifted between scan and cleanup.
struct QuickCleanCleanedCategory: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let icon: String
    let tint: Color
    let domain: StorageDomain
    let safety: CleanupSafety
    /// Bytes actually reclaimed for items in this category. May be less than
    /// the scanned size when a deletion failed or when on-disk size changed
    /// between scan and cleanup.
    let reclaimedBytes: Int64
    /// Items that were successfully moved to Trash (or permanently deleted
    /// from inside it), in scan order. Excludes items that failed.
    let reclaimedItems: [QuickCleanItem]

    var itemCount: Int { reclaimedItems.count }
    var isEmpty: Bool { reclaimedItems.isEmpty }
}

extension QuickCleanScan {
    /// Builds the per-category success view model from a `CleanupResult`.
    /// A category is included only if at least one of its items was
    /// successfully cleaned. Failed items are filtered out so the success
    /// breakdown reflects the real outcome, not the pre-scan estimate.
    func cleanedCategories(in result: CleanupResult) -> [QuickCleanCleanedCategory] {
        let deletedBytesByURL = Dictionary(
            result.deletedItems.map { ($0.originalURL, $0.bytesReclaimed) },
            uniquingKeysWith: { first, _ in first }
        )
        let failedURLs = Set(result.failedURLs.map(\.0))

        return populatedCategories.compactMap { category in
            let reclaimedItems = category.items.compactMap { item -> QuickCleanItem? in
                guard let bytes = deletedBytesByURL[item.url], bytes > 0 else { return nil }
                guard !failedURLs.contains(item.url) else { return nil }
                return QuickCleanItem(url: item.url, bytes: bytes)
            }
            guard !reclaimedItems.isEmpty else { return nil }
            let reclaimedBytes = reclaimedItems.reduce(Int64(0)) { $0 + $1.bytes }
            return QuickCleanCleanedCategory(
                id: category.id,
                name: category.name,
                icon: category.icon,
                tint: category.tint,
                domain: category.domain,
                safety: category.safety,
                reclaimedBytes: reclaimedBytes,
                reclaimedItems: reclaimedItems
            )
        }
    }
}
