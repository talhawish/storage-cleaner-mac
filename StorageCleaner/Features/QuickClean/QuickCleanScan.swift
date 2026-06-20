import Foundation

/// One file or directory that Quick Clean discovered. The `id` is the canonical
/// file URL so the same path can never appear twice in a single scan result,
/// even if two `CleanupOption`s share overlapping roots.
struct QuickCleanItem: Identifiable, Hashable, Sendable {
    let url: URL
    let bytes: Int64

    var id: URL { url }

    var isDirectory: Bool { url.hasDirectoryPath }
    var displayName: String { url.lastPathComponent }
    var parentPath: String { url.deletingLastPathComponent().path }
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
    let iconColor: String
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
