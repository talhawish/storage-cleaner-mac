import SwiftUI

/// Lists loose installer and package leftovers (DMG, PKG, IPA, ISO, APK, …) discovered in Downloads,
/// Desktop, and Documents, and lets the user review and move selected items to the Trash. Mirrors the
/// review-safe, select-and-delete flow of `LargeFilesView` for a familiar interaction.
struct LeftoversView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void

    @State private var typeFilter: LeftoverTypeFilter = .all
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false

    private var allRecords: [LeftoverRecord] {
        findings.flatMap { finding in
            finding.filePaths.map { url in
                LeftoverRecord(
                    url: url,
                    kind: finding.kind,
                    bytes: StorageFormatting.fileSize(at: url)
                )
            }
        }
    }

    private var filteredRecords: [LeftoverRecord] {
        allRecords
            .filter { typeFilter.contains($0.kind) }
            .sorted { $0.bytes > $1.bytes }
    }

    private var totalBytes: Int64 {
        filteredRecords.reduce(0) { $0 + $1.bytes }
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in
            total + StorageFormatting.fileSize(at: url)
        }
    }

    var body: some View {
        Group {
            if allRecords.isEmpty {
                AnimatedEmptyState(
                    title: "No Leftover Installers",
                    message: "Run a scan to find leftover disk images, packages, and app bundles "
                        + "(DMG, PKG, IPA, ISO, APK) in Downloads, Desktop, and Documents.",
                    actionTitle: "Scan Leftovers",
                    systemImage: "archivebox",
                    action: onScan
                )
            } else {
                content
            }
        }
        .navigationTitle("Leftovers")
        .navigationSubtitle("\(filteredRecords.count) items · \(StorageFormatting.bytes(totalBytes))")
        .accessibilityIdentifier("leftovers-root")
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
                    Label("Scan Leftovers", systemImage: "sparkle.magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan for leftover installers again")
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
}

private struct LeftoverRecord: Identifiable, Equatable {
    let url: URL
    let kind: StorageFindingKind
    let bytes: Int64

    var id: URL { url }
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
