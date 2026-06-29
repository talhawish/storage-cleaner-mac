import SwiftUI

struct LargeFilesView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void
    let permissionHandler: (any StoragePermissionHandling)?
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @AppStorage(LargeFileThreshold.storageKey)
    private var largeFileThresholdMB = LargeFileThreshold.defaultMegabytes
    @State private var locationFilter: LargeFileLocationFilter = .all
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false
    @State private var previewURL: URL?
    @State private var allLargeFileRecords: [FindingFileRecord] = []
    @State private var isLoadingRecords = false

    private var thresholdBytes: Int64 { Int64(largeFileThresholdMB) * 1_000_000 }
    private var recordsIdentity: FindingFileRecordsIdentity { FindingFileRecordsIdentity(findings: findings) }
    private var hasScannedPaths: Bool { findings.contains { !$0.filePaths.isEmpty } }
    private var loadedLargeFileRecords: [FindingFileRecord] { hasScannedPaths ? allLargeFileRecords : [] }
    private var isPreparingRecords: Bool { hasScannedPaths && (isLoadingRecords || loadedLargeFileRecords.isEmpty) }

    private var largeFileRecords: [FindingFileRecord] {
        locationFilteredRecords
            .filter { $0.bytes >= thresholdBytes }
            .sorted { $0.bytes > $1.bytes }
    }

    private var locationFilteredRecords: [FindingFileRecord] {
        loadedLargeFileRecords
            .filter { locationFilter.contains($0.url) }
    }

    private var totalBytes: Int64 {
        largeFileRecords.reduce(0) { $0 + $1.bytes }
    }

    private var totalSelectedBytes: Int64 {
        FindingFileRecordBuilder.totalSelectedBytes(selectedURLs: selectedURLs, records: loadedLargeFileRecords)
    }

    var body: some View {
        Group {
            if isPreparingRecords {
                preparingRecordsView
            } else if allLargeFileRecords.isEmpty {
                EmptyStateView(
                    title: "Nothing to clean here",
                    message: "No review-safe large files turned up in the selected locations. "
                        + "Lower the minimum size to see more, or scan again to refresh.",
                    systemImage: "checkmark.seal.fill",
                    tint: AppTheme.mint,
                    actionTitle: "Scan Again",
                    action: onScan
                )
            } else {
                largeFilesContent
            }
        }
        .navigationTitle("Large Files")
        .navigationSubtitle("\(largeFileRecords.count) items · \(StorageFormatting.bytes(totalBytes))")
        .accessibilityIdentifier("large-files-root")
        .task(id: recordsIdentity) {
            await loadRecords()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !selectedURLs.isEmpty {
                    Button {
                        requestDeleteConfirmation()
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }

            ToolbarItem {
                Button {
                    onScan()
                } label: {
                    Label("Scan Large Files", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan large-file locations again")
            }
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            ConfirmationModal(
                variant: .destructive,
                title: "Move \(selectedURLs.count) item\(selectedURLs.count == 1 ? "" : "s") to Trash?",
                message: "This will move \(selectedURLs.count) item\(selectedURLs.count == 1 ? "" : "s") "
                    + "(\(StorageFormatting.bytes(totalSelectedBytes))) to Trash.",
                iconSystemName: "trash.fill",
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Move to Trash",
                    systemImage: "trash.fill",
                    isProminent: true,
                    isDestructive: true,
                    isDefault: true,
                    action: {
                        let urls = Array(selectedURLs)
                        selectedURLs.removeAll()
                        onDelete(urls)
                    }
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
        .sheet(isPresented: Binding(
            get: { previewURL != nil },
            set: { if !$0 { previewURL = nil } }
        )) {
            if let url = previewURL {
                MediaPreviewSheet(
                    url: url,
                    permissionHandler: permissionHandler,
                    canRevealInFinder: canUseProActions
                )
            }
        }
    }

    private var preparingRecordsView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Calculating file sizes")
                .font(.headline)
            Text("Large folders are measured in the background before filtering.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculating large file sizes")
    }

    private var largeFilesContent: some View {
        List {
            locationSection
            thresholdSection

            if largeFileRecords.isEmpty {
                noMatchesSection
            } else {
                filesSection
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var locationSection: some View {
        Section {
            Picker("Location", selection: $locationFilter) {
                ForEach(LargeFileLocationFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Location")
        }
    }

    private var thresholdSection: some View {
        Section {
            Picker("Minimum size", selection: $largeFileThresholdMB) {
                ForEach(LargeFileThreshold.allCases) { threshold in
                    Text(threshold.label)
                        .tag(threshold.megabytes)
                        .accessibilityIdentifier("large-file-threshold-\(threshold.megabytes)")
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("large-file-threshold-picker")
        } header: {
            Text("Minimum size")
        }
    }

    private var filesSection: some View {
        Section {
            ForEach(largeFileRecords) { record in
                FileRowView(
                    url: record.url,
                    isSelected: selectedURLs.contains(record.url),
                    pathDisplayMode: .fullPath,
                    metadata: record.detailMetadata,
                    canRevealInFinder: canUseProActions,
                    onToggle: { toggle(record.url) },
                    onPreview: { previewURL = record.url }
                )
            }
        } header: {
            SectionHeader(
                title: "Review-safe files over \(StorageFormatting.bytes(thresholdBytes))",
                systemImage: "doc.badge.ellipsis"
            ) {
                Text(StorageFormatting.bytes(totalBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var noMatchesSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                Text("No files over \(StorageFormatting.bytes(thresholdBytes))")
                    .font(.headline)
                Text(noMatchesMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
    }

    private var noMatchesMessage: String {
        if locationFilteredRecords.isEmpty {
            return "Choose another location or scan again to refresh this folder."
        }

        return "Choose a smaller minimum size to see the scanned files again."
    }

    private func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    private func requestDeleteConfirmation() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        showDeleteConfirmation = true
    }

    private func loadRecords() async {
        let findings = findings
        isLoadingRecords = true
        let records = await Task.detached(priority: .utility) {
            FindingFileRecordBuilder.records(from: findings)
        }.value
        guard !Task.isCancelled else { return }

        allLargeFileRecords = records
        selectedURLs.formIntersection(Set(records.map(\.url)))
        isLoadingRecords = false
    }
}

private enum LargeFileLocationFilter: String, CaseIterable {
    case all
    case desktop
    case downloads
    case documents
    case pictures
    case movies

    var title: String {
        switch self {
        case .all: "All"
        case .desktop: "Desktop"
        case .downloads: "Downloads"
        case .documents: "Documents"
        case .pictures: "Pictures"
        case .movies: "Movies"
        }
    }

    func contains(_ url: URL) -> Bool {
        guard self != .all else { return true }
        return url.standardizedFileURL.pathComponents.contains(title)
    }
}
