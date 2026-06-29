import SwiftUI

/// Lists orphaned app data and stale crash reports across `~/Library` and lets the user review
/// and move selected items to the Trash. The list is dynamically discovered at scan time — what
/// appears depends on which apps are installed and what they've left behind in user Library.
struct SystemJunkView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var typeFilter: SystemJunkTypeFilter = .all
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false

    /// Per-filter aggregates from the scan results — bytes and item counts are pre-computed off
    /// the main thread by the scanner, so they are correct for both files and directories
    /// (unlike the per-URL `StorageFormatting.fileSize(at:)`, which returns 0 for folders).
    private var findingsByFilter: [SystemJunkTypeFilter: (bytes: Int64, count: Int)] {
        let grouped = Dictionary(grouping: findings, by: { SystemJunkTypeFilter.filter(for: $0.kind) })
        var result: [SystemJunkTypeFilter: (bytes: Int64, count: Int)] = [:]
        for (filter, items) in grouped {
            result[filter] = (
                bytes: items.reduce(0) { $0 + $1.bytes },
                count: items.reduce(0) { $0 + $1.itemCount }
            )
        }
        return result
    }

    private func bytes(for filter: SystemJunkTypeFilter) -> Int64 {
        if filter == .all {
            return findings.reduce(0) { $0 + $1.bytes }
        }
        return findingsByFilter[filter]?.bytes ?? 0
    }

    private func itemCount(for filter: SystemJunkTypeFilter) -> Int {
        if filter == .all {
            return findingsByFilter.values.reduce(0) { $0 + $1.count }
        }
        return findingsByFilter[filter]?.count ?? 0
    }

    /// Flat list of every URL we know about, kept for the per-row `FileRowView` and the
    /// per-URL selection summary. Per-URL bytes come from the scan's precomputed
    /// `pathBytes` dictionary so the list shows accurate sizes immediately.
    private var allRecords: [SystemJunkRecord] {
        findings.flatMap { finding in
            finding.filePaths.map { url in
                SystemJunkRecord(url: url, kind: finding.kind, bytes: finding.pathBytes[url] ?? 0)
            }
        }
    }

    private var filteredRecords: [SystemJunkRecord] {
        allRecords
            .filter { typeFilter.contains($0.kind) }
            .sorted { $0.bytes > $1.bytes }
    }

    private var detectedSubTypeCount: Int {
        findingsByFilter.keys.filter { $0 != .all }.count
    }

    /// `true` when every URL currently visible in the list is already in `selectedURLs`. Used by
    /// the toolbar's "Select All" / "Deselect All" toggle to choose its label and behaviour.
    private var allVisibleSelected: Bool {
        let visibleURLs = filteredRecords.map(\.url)
        guard !visibleURLs.isEmpty else { return false }
        return visibleURLs.allSatisfy { selectedURLs.contains($0) }
    }

    private var selectAllButtonTitle: String {
        allVisibleSelected ? "Deselect All" : "Select All"
    }

    /// Count of selected URLs that are visible in the current filter — NOT the global total.
    /// The Clean button label and the confirmation modal only count what the user can see, so
    /// switching between category tabs doesn't silently bundle items from other categories.
    private var visibleSelectedCount: Int {
        let visibleSet = Set(filteredRecords.map(\.url))
        return selectedURLs.intersection(visibleSet).count
    }

    /// The URLs the destructive confirmation should act on — always scoped to the current
    /// filter so "Clean 4 Selected" on the App Data tab only trashes App Data items.
    private var confirmingURLs: [URL] {
        let visibleSet = Set(filteredRecords.map(\.url))
        return selectedURLs.filter { visibleSet.contains($0) }
    }

    /// Byte total for the confirmation. When every visible item is selected, use the scanner's
    /// pre-measured finding total (accurate for directories). Otherwise approximate.
    private var confirmingByteTotal: Int64 {
        guard !confirmingURLs.isEmpty else { return 0 }
        if allVisibleSelected {
            return bytes(for: typeFilter)
        }
        let sizesByURL = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.url, $0.bytes) })
        return confirmingURLs.reduce(Int64(0)) { $0 + (sizesByURL[$1] ?? 0) }
    }

    /// Label for the inline destructive button. When nothing visible is selected it reads
    /// "Clean All" (one-click bulk action). Once the user has hand-picked items in the current
    /// category, it shows "Clean N Selected" — only counting selections in the current view.
    private var cleanButtonTitle: String {
        if visibleSelectedCount > 0 { return "Clean \(visibleSelectedCount) Selected" }
        return "Clean All"
    }

    private var subtitle: String {
        let total = bytes(for: typeFilter)
        let count = filteredRecords.count
        guard count > 0 else { return "No orphaned app data detected" }
        return "\(count) items · \(StorageFormatting.bytes(total))"
    }

    var body: some View {
        Group {
            if allRecords.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("System Junk")
        .navigationSubtitle(subtitle)
        .accessibilityIdentifier("system-junk-root")
        .toolbar {
            ToolbarItem {
                Button {
                    onScan()
                } label: {
                    Label("Scan System Junk", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Re-scan orphaned app data and crash reports")
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmationModal(
                variant: .destructive,
                title: "Move \(confirmingURLs.count) item\(confirmingURLs.count == 1 ? "" : "s") to Trash?",
                message: "This will move \(confirmingURLs.count) item\(confirmingURLs.count == 1 ? "" : "s") "
                    + "(\(StorageFormatting.bytes(confirmingByteTotal))) to Trash.",
                iconSystemName: "trash.fill",
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Move to Trash",
                    systemImage: "trash.fill",
                    isProminent: true,
                    isDestructive: true,
                    isDefault: true,
                    action: {
                        let urls = confirmingURLs
                        for url in urls { selectedURLs.remove(url) }
                        onDelete(urls)
                    }
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
    }

    /// Selects every URL currently visible in the list, or clears the visible selection when every
    /// visible URL is already selected. Other (filtered-out) selections are preserved so users can
    /// build a selection across multiple categories before confirming.
    private func toggleSelectAll() {
        let visibleURLs = filteredRecords.map(\.url)
        guard !visibleURLs.isEmpty else { return }
        if allVisibleSelected {
            for url in visibleURLs {
                selectedURLs.remove(url)
            }
        } else {
            for url in visibleURLs {
                selectedURLs.insert(url)
            }
        }
    }

    /// Pre-selects every URL in the current view, then opens the confirmation. Used by the
    /// "Clean All" button so the most common bulk action is a single click. No-ops when the
    /// visible list is empty (nothing to select).
    private func requestCleanAll() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        let visibleURLs = filteredRecords.map(\.url)
        guard !visibleURLs.isEmpty else { return }
        for url in visibleURLs {
            selectedURLs.insert(url)
        }
        showDeleteConfirmation = true
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "Nothing to clean here",
            message: "Your installed apps line up cleanly with their Library entries, and no "
                + "stale crash reports turned up. Scan again to keep it that way.",
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: onScan
        )
    }

    private var content: some View {
        List {
            statsSection

            if filteredRecords.isEmpty {
                noMatchesSection
            } else {
                filesSection
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var statsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(SystemJunkTypeFilter.allCases.enumerated()), id: \.element.id) { _, filter in
                        StatCardTab(
                            title: filter.title,
                            count: count(forStatCard: filter),
                            bytes: bytes(for: filter),
                            systemImage: filter.systemImage,
                            tint: filter.tint,
                            isSelected: typeFilter == filter,
                            countLabel: countLabel(for: filter)
                        ) {
                            typeFilter = filter
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 14, trailing: 18))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            SectionHeader(
                title: "System Junk Categories",
                subtitle: "Tap a category to filter the files below",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func count(forStatCard filter: SystemJunkTypeFilter) -> Int {
        if filter == .all {
            return detectedSubTypeCount
        }
        return findingsByFilter[filter]?.count ?? 0
    }

    private func countLabel(for filter: SystemJunkTypeFilter) -> String {
        filter == .all ? "categories" : "items"
    }

    private var filesSection: some View {
        Section {
            selectionBar
                .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(filteredRecords) { record in
                FileRowView(
                    url: record.url,
                    isSelected: selectedURLs.contains(record.url),
                    pathDisplayMode: .fullPath,
                    precomputedBytes: record.bytes,
                    canRevealInFinder: canUseProActions,
                    onToggle: { toggle(record.url) }
                )
            }
        } header: {
            SectionHeader(
                title: typeFilter == .all ? "All orphaned & stale data" : typeFilter.sectionTitle,
                systemImage: typeFilter.systemImage
            ) {
                Text(StorageFormatting.bytes(bytes(for: typeFilter)))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Inline action bar above the file list. The master checkbox toggles every visible item;
    /// the destructive button on the right acts as the one-click "Clean All" when nothing is
    /// selected and as "Clean N Selected" once the user has hand-picked a subset.
    private var selectionBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { allVisibleSelected },
                set: { _ in toggleSelectAll() }
            )) {
                HStack(spacing: 6) {
                    Text(selectAllButtonTitle)
                        .font(.subheadline.weight(.medium))
                    Text(selectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .toggleStyle(.checkbox)
            .accessibilityIdentifier("system-junk-select-all")
            .help(
                allVisibleSelected
                    ? "Deselect every file in this category"
                    : "Select every file in this category"
            )

            Spacer(minLength: 8)

            Button(role: .destructive) {
                guard canUseProActions else {
                    onRequirePro()
                    return
                }
                if visibleSelectedCount > 0 {
                    showDeleteConfirmation = true
                } else {
                    requestCleanAll()
                }
            } label: {
                Label(cleanButtonTitle, systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.regular)
            .disabled(visibleSelectedCount == 0 && filteredRecords.isEmpty)
            .accessibilityIdentifier("system-junk-clean-button")
            .help(
                visibleSelectedCount > 0
                    ? "Move \(visibleSelectedCount) selected "
                        + "\(visibleSelectedCount == 1 ? "item" : "items") to Trash"
                    : "Move every file in this category to Trash"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private var selectionSummary: String {
        let total = filteredRecords.count
        let selectedInView = filteredRecords
            .map(\.url)
            .filter { selectedURLs.contains($0) }
            .count
        if selectedInView == 0 { return "0 of \(total) selected" }
        if selectedInView == total { return "all \(total) selected" }
        return "\(selectedInView) of \(total) selected"
    }

    private var noMatchesSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                Text(emptyStateTitle)
                    .font(.headline)
                Text("Choose another category or scan again to refresh these locations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
    }

    private var emptyStateTitle: String {
        switch typeFilter {
        case .all: "No system junk found"
        case .appSupport: "No orphaned app data found"
        case .caches: "No orphaned app caches found"
        case .containers: "No orphaned app containers found"
        case .preferences: "No orphaned app preferences found"
        case .crashReports: "No old crash reports found"
        }
    }

    private func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }
}

private struct SystemJunkRecord: Identifiable, Equatable {
    let url: URL
    let kind: StorageFindingKind
    let bytes: Int64

    var id: URL { url }
}

enum SystemJunkTypeFilter: String, CaseIterable, Identifiable {
    case all
    case appSupport
    case caches
    case containers
    case preferences
    case crashReports

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "All"
        case .appSupport: "App Data"
        case .caches: "Caches"
        case .containers: "Containers"
        case .preferences: "Preferences"
        case .crashReports: "Crash Reports"
        }
    }

    var sectionTitle: String {
        switch self {
        case .all: "All orphaned & stale data"
        case .appSupport: "Orphaned app data"
        case .caches: "Orphaned app caches"
        case .containers: "Orphaned app containers"
        case .preferences: "Orphaned app preferences"
        case .crashReports: "Old crash reports"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "trash.slash.fill"
        case .appSupport: "externaldrive.fill"
        case .caches: "internaldrive.fill"
        case .containers: "shippingbox.fill"
        case .preferences: "slider.horizontal.3"
        case .crashReports: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: AppTheme.rose
        case .appSupport: AppTheme.rose
        case .caches: AppTheme.orange
        case .containers: AppTheme.violet
        case .preferences: AppTheme.indigo
        case .crashReports: AppTheme.amber
        }
    }

    func contains(_ kind: StorageFindingKind) -> Bool {
        if self == .all {
            // `.all` matches every system-junk sub-kind. The view is only handed findings
            // already filtered to system-junk kinds, so this is safe.
            return Self.filter(for: kind) != .all
        }
        return Self.filter(for: kind) == self
    }

    static func filter(for kind: StorageFindingKind) -> SystemJunkTypeFilter {
        switch kind {
        case .orphanedAppSupport: .appSupport
        case .orphanedAppCaches: .caches
        case .orphanedAppContainers: .containers
        case .orphanedAppPreferences: .preferences
        case .oldCrashReports: .crashReports
        default: .all
        }
    }
}
