import Foundation
import Observation
import SwiftUI

/// Drives the Quick Clean modal: runs the scan, exposes the per-category
/// results, and coordinates user selections through to the final cleanup.
///
/// Extracted from `QuickCleanView` so the view stays declarative and the
/// stateful logic (selection bookkeeping, phase transitions, progress) is
/// independently testable.
@MainActor
@Observable
final class QuickCleanViewModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case review
        case cleaning
        case success
    }

    /// Live progress reported by the scanner. The view uses this to render a
    /// "Scanning N of M categories" copy during the scan.
    struct Progress: Equatable {
        var completedCategories: Int = 0
        var totalCategories: Int = 0

        var fraction: Double {
            guard totalCategories > 0 else { return 0 }
            return min(1, Double(completedCategories) / Double(totalCategories))
        }

        var isIndeterminate: Bool { totalCategories == 0 }
    }

    private(set) var phase: Phase = .idle
    private(set) var progress = Progress()
    private(set) var scan: QuickCleanScan = QuickCleanScan(categories: [])
    private(set) var selection: Set<URL> = []
    private(set) var lastResult: CleanupResult?
    /// Free-bytes snapshot captured the moment the user opens the modal. Drives
    /// the "free before / after" pill in the success view when a cleanup ran.
    private(set) var freeBytesAtStart: Int64?
    /// Free-bytes snapshot captured after the cleanup returns. Lets the success
    /// view show the volume's actual free space after the move to Trash, even
    /// when other apps are still writing.
    private(set) var freeBytesAtEnd: Int64?

    private let onClean: @MainActor ([URL]) async -> CleanupResult
    private let volumeProvider: @MainActor () async -> Int64?
    private var scanTask: Task<Void, Never>?

    init(
        onClean: @escaping @MainActor ([URL]) async -> CleanupResult,
        volumeProvider: @escaping @MainActor () async -> Int64? = { nil }
    ) {
        self.onClean = onClean
        self.volumeProvider = volumeProvider
    }

    // MARK: - Derived state

    var totalSelectedBytes: Int64 {
        scan.selectedBytes(in: selection)
    }

    var totalSelectedItems: Int {
        selection.count
    }

    var populatedCategories: [QuickCleanCategory] {
        scan.populatedCategories
    }

    var hasSelection: Bool { !selection.isEmpty }

    var isScanning: Bool {
        if case .scanning = phase { return true }
        return false
    }

    // MARK: - Phase transitions

    func startScan() {
        cancelScan()
        phase = .scanning
        progress = Progress()
        scan = QuickCleanScan(categories: [])
        selection = []
        lastResult = nil
        freeBytesAtStart = nil
        freeBytesAtEnd = nil
        Task { @MainActor [weak self] in
            self?.freeBytesAtStart = await self?.volumeProvider()
        }

        let scanner = QuickCleanScanner()
        scanTask = Task { [weak self] in
            let result = await scanner.scan { completed, total in
                await MainActor.run {
                    self?.progress = Progress(
                        completedCategories: completed,
                        totalCategories: total
                    )
                }
            }
            guard !Task.isCancelled else { return }
            self?.handleScanComplete(result)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    func performCleanup() {
        let urls = selection.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        guard !urls.isEmpty else { return }
        phase = .cleaning

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await onClean(urls)
            lastResult = result
            freeBytesAtEnd = await self.volumeProvider()
            phase = .success
        }
    }

    // MARK: - Selection

    func isSelected(_ url: URL) -> Bool {
        selection.contains(url)
    }

    func toggle(_ url: URL) {
        if selection.contains(url) {
            selection.remove(url)
        } else {
            selection.insert(url)
        }
    }

    func selectAll() {
        selection = Set(scan.allItems.map(\.url))
    }

    func deselectAll() {
        selection.removeAll()
    }

    func toggleCategory(_ category: QuickCleanCategory) {
        let categoryURLs = Set(category.items.map(\.url))
        if category.items.allSatisfy({ selection.contains($0.url) }) {
            selection.subtract(categoryURLs)
        } else {
            selection.formUnion(categoryURLs)
        }
    }

    func isCategoryFullySelected(_ category: QuickCleanCategory) -> Bool {
        !category.items.isEmpty && category.items.allSatisfy { selection.contains($0.url) }
    }

    func isCategoryPartiallySelected(_ category: QuickCleanCategory) -> Bool {
        let hits = category.items.filter { selection.contains($0.url) }.count
        return hits > 0 && hits < category.items.count
    }

    // MARK: - Internals

    private func handleScanComplete(_ result: QuickCleanScan) {
        scan = result
        progress = Progress(
            completedCategories: result.categories.count,
            totalCategories: result.categories.count
        )
        if result.populatedCategories.isEmpty {
            phase = .success
            lastResult = CleanupResult(
                deletedURLs: [],
                deletedItems: [],
                failedURLs: [],
                totalBytesReclaimed: 0
            )
        } else {
            selection = Set(result.allItems.map(\.url))
            phase = .review
        }
    }
}

extension QuickCleanViewModel {
    /// Test seam: feeds a pre-computed scan result into the view model and
    /// drives the same transitions a real scan would. Keeps the public
    /// `startScan` API as the production path.
    func setScanResultForTesting(_ result: QuickCleanScan) {
        cancelScan()
        handleScanComplete(result)
    }
}
