import SwiftUI

/// Lists loose installer and package leftovers (DMG, PKG, IPA, ISO, APK, …) discovered in Downloads,
/// Desktop, and Documents, and lets the user review and move selected items to the Trash. Mirrors the
/// review-safe, select-and-delete flow of `LargeFilesView` for a familiar interaction.
struct LeftoversView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var typeFilter: LeftoverTypeFilter = .all
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false
    @State private var allRecords: [FindingFileRecord] = []
    @State private var isLoadingRecords = false

    private var recordsIdentity: FindingFileRecordsIdentity { FindingFileRecordsIdentity(findings: findings) }
    private var hasScannedPaths: Bool { findings.contains { !$0.filePaths.isEmpty } }
    private var loadedRecords: [FindingFileRecord] { hasScannedPaths ? allRecords : [] }
    private var isPreparingRecords: Bool { hasScannedPaths && (isLoadingRecords || loadedRecords.isEmpty) }

    private var filteredRecords: [FindingFileRecord] {
        loadedRecords
            .filter { typeFilter.contains($0.kind) }
            .sorted { $0.bytes > $1.bytes }
    }

    private var totalBytes: Int64 {
        filteredRecords.reduce(0) { $0 + $1.bytes }
    }

    private var totalSelectedBytes: Int64 {
        FindingFileRecordBuilder.totalSelectedBytes(selectedURLs: selectedURLs, records: loadedRecords)
    }

    var body: some View {
        Group {
            if isPreparingRecords {
                preparingRecordsView
            } else if allRecords.isEmpty {
                EmptyStateView(
                    title: "Nothing to clean here",
                    message: "No leftover disk images, packages, or app bundles turned up in the "
                        + "selected locations. Run another scan to refresh.",
                    systemImage: "checkmark.seal.fill",
                    tint: AppTheme.mint,
                    actionTitle: "Scan Again",
                    action: onScan
                )
            } else {
                content
            }
        }
        .navigationTitle("Leftovers")
        .navigationSubtitle("\(filteredRecords.count) items · \(StorageFormatting.bytes(totalBytes))")
        .accessibilityIdentifier("leftovers-root")
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
                    Label("Scan Leftovers", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan for leftover installers again")
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
    }

    private var preparingRecordsView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Calculating leftover sizes")
                .font(.headline)
            Text("Installer packages are measured in the background before filtering.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculating leftover sizes")
    }

    private var content: some View {
        List {
            typeSection

            if filteredRecords.isEmpty {
                noMatchesSection
            } else {
                filesSection
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $typeFilter) {
                ForEach(LeftoverTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Type")
        }
    }

    private var filesSection: some View {
        Section {
            ForEach(filteredRecords) { record in
                FileRowView(
                    url: record.url,
                    isSelected: selectedURLs.contains(record.url),
                    pathDisplayMode: .fullPath,
                    metadata: record.detailMetadata,
                    canRevealInFinder: canUseProActions,
                    onToggle: { toggle(record.url) }
                )
            }
        } header: {
            SectionHeader(
                title: "Review-safe leftovers",
                systemImage: "archivebox.fill"
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
                Text("No \(typeFilter.title.lowercased()) leftovers")
                    .font(.headline)
                Text("Choose another type or scan again to refresh these locations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
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

        allRecords = records
        selectedURLs.formIntersection(Set(records.map(\.url)))
        isLoadingRecords = false
    }
}

private enum LeftoverTypeFilter: String, CaseIterable {
    case all
    case installers
    case appPackages

    var title: String {
        switch self {
        case .all: "All"
        case .installers: "Installers"
        case .appPackages: "App Packages"
        }
    }

    func contains(_ kind: StorageFindingKind) -> Bool {
        switch self {
        case .all: true
        case .installers: kind == .installerLeftovers
        case .appPackages: kind == .androidPackages
        }
    }
}
