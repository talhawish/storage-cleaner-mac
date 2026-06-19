import SwiftUI

struct LargeFilesView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void

    @State private var thresholdBytes: Int64 = 100_000_000
    @State private var locationFilter: LargeFileLocationFilter = .all
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false

    private let thresholdOptions: [(String, Int64)] = [
        ("10 MB", 10_000_000),
        ("50 MB", 50_000_000),
        ("100 MB", 100_000_000),
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000),
        ("5 GB", 5_000_000_000)
    ]

    private var largeFileRecords: [LargeFileRecord] {
        locationFilteredRecords
            .filter { $0.bytes >= thresholdBytes }
            .sorted { $0.bytes > $1.bytes }
    }

    private var locationFilteredRecords: [LargeFileRecord] {
        allLargeFileRecords
            .filter { locationFilter.contains($0.url) }
    }

    private var allLargeFileRecords: [LargeFileRecord] {
        findings
            .flatMap { finding in
                finding.filePaths.map { url in
                    LargeFileRecord(
                        url: url,
                        kind: finding.kind,
                        domain: finding.domain,
                        bytes: StorageFormatting.fileSize(at: url)
                    )
                }
            }
    }

    private var totalBytes: Int64 {
        largeFileRecords.reduce(0) { $0 + $1.bytes }
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in
            total + StorageFormatting.fileSize(at: url)
        }
    }

    var body: some View {
        Group {
            if allLargeFileRecords.isEmpty {
                AnimatedEmptyState(
                    title: "No Large Files",
                    message: "Run a scan to find review-safe large files in Desktop, Downloads, "
                        + "Documents, Pictures, and Movies.",
                    actionTitle: "Scan Large Files",
                    systemImage: "doc.badge.ellipsis",
                    action: onScan
                )
            } else {
                largeFilesContent
            }
        }
        .navigationTitle("Large Files")
        .navigationSubtitle("\(largeFileRecords.count) items · \(StorageFormatting.bytes(totalBytes))")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !selectedURLs.isEmpty {
                    Button {
                        showDeleteConfirmation = true
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
                    Label("Scan Large Files", systemImage: "sparkle.magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan large-file locations again")
            }
        }
        .confirmationDialog(
            "Move \(selectedURLs.count) items to Trash?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                let urls = Array(selectedURLs)
                selectedURLs.removeAll()
                onDelete(urls)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This will move \(selectedURLs.count) items "
                    + "(\(StorageFormatting.bytes(totalSelectedBytes))) to Trash."
            )
        }
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
            Picker("Minimum size", selection: $thresholdBytes) {
                ForEach(thresholdOptions, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .pickerStyle(.segmented)
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
                    onToggle: { toggle(record.url) }
                )
            }
        } header: {
            HStack {
                Image(systemName: "doc.badge.ellipsis")
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                Text("Review-safe files over \(StorageFormatting.bytes(thresholdBytes))")
                Spacer()
                Text(StorageFormatting.bytes(totalBytes))
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
}

private struct LargeFileRecord: Identifiable, Equatable {
    let url: URL
    let kind: StorageFindingKind
    let domain: StorageDomain
    let bytes: Int64

    var id: URL { url }
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
