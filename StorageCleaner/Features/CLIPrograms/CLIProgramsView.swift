import SwiftUI

struct CLIProgramsView: View {
    let findings: [StorageFinding]
    let emptyStateMessage: String
    let onScan: () -> Void
    let onRemove: ([URL]) async -> Void

    @State private var selectedURLs: Set<URL> = []
    @State private var searchText = ""
    @State private var sortOption: SortOption = .sizeDesc
    @State private var programs: [CLIProgram] = []
    @State private var sizes: [URL: Int64] = [:]
    @State private var isLoading = true
    @State private var detailProgram: CLIProgram?
    @State private var showDeleteConfirmation = false
    @State private var loadTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    enum SortOption: String, CaseIterable {
        case sizeDesc = "Largest First"
        case nameAsc = "Name A–Z"

        var systemImage: String {
            switch self {
            case .sizeDesc: "arrow.down"
            case .nameAsc: "textformat"
            }
        }
    }

    private var allPrograms: [CLIProgram] {
        programs
    }

    private var filteredPrograms: [CLIProgram] {
        guard !searchText.isEmpty else { return allPrograms }
        return allPrograms.filter { program in
            program.displayName.localizedCaseInsensitiveContains(searchText)
                || program.subtitle.localizedCaseInsensitiveContains(searchText)
                || program.url.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Programs grouped into sections, ordered by category then sort option.
    private var sections: [(category: CLIProgramCategory, programs: [CLIProgram])] {
        let grouped = Dictionary(grouping: filteredPrograms, by: \.category)
        return grouped.keys
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { category in
                (category, sorted(grouped[category] ?? []))
            }
    }

    private var totalBytes: Int64 {
        // Once sizes are measured they reflect exactly what's listed (including
        // global Node packages the scan never saw); fall back to scan totals
        // while sizing is still in flight.
        if !sizes.isEmpty {
            return sizes.values.reduce(0, +)
        }
        return findings.reduce(0) { $0 + $1.bytes }
    }

    private var selectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { $0 + (sizes[$1] ?? 0) }
    }

    private var allVisibleSelected: Bool {
        !filteredPrograms.isEmpty && filteredPrograms.allSatisfy { selectedURLs.contains($0.url) }
    }

    var body: some View {
        Group {
            if isLoading && programs.isEmpty {
                loadingState
            } else if allPrograms.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("CLI Programs & Toolchains")
        .navigationSubtitle("\(allPrograms.count) programs · \(StorageFormatting.bytes(totalBytes))")
        .accessibilityIdentifier("cli-programs-root")
        .toolbar { toolbarContent }
        .onAppear { startLoading() }
        .onChange(of: rootsKey, initial: false) { _, _ in startLoading() }
        .onDisappear { cancelLoading() }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                finding: deletionFinding,
                selectedURLs: Array(selectedURLs),
                totalBytes: selectedBytes,
                onDelete: {
                    let urls = Array(selectedURLs)
                    selectedURLs.removeAll()
                    Task {
                        await onRemove(urls)
                        startLoading()
                    }
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
        .sheet(item: $detailProgram) { program in
            CLIProgramDetailSheet(program: program, size: sizes[program.url])
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !selectedURLs.isEmpty {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .help("Delete \(selectedURLs.count) selected items")
            }
        }

        ToolbarItem {
            Button {
                onScan()
            } label: {
                Label("Scan Now", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .help("Scan CLI tool locations again")
        }

        ToolbarItem {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .accessibilityLabel("Sort")
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header

            Divider()

            SearchField(text: $searchText, prompt: "Search tools…")
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            selectionBar

            programList
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.teal.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "terminal.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.teal)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("CLI Programs & Toolchains")
                    .font(.title2.weight(.semibold))
                Text("Homebrew, version managers, and installed command-line toolchains")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormatting.bytes(totalBytes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("\(allPrograms.count) tools")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button {
                toggleAllVisible()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allVisibleSelected ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(allVisibleSelected ? AppTheme.accent : .secondary)
                        .accessibilityHidden(true)
                    Text(allVisibleSelected ? "Deselect All" : "Select All")
                        .font(.subheadline.weight(.medium))
                }
            }
            .buttonStyle(.plain)

            if !selectedURLs.isEmpty {
                Divider().frame(height: 16)

                Text("\(selectedURLs.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())

                Text(StorageFormatting.bytes(selectedBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer()

            Text("\(filteredPrograms.count) of \(allPrograms.count) tools")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedURLs.count)
    }

    private var programList: some View {
        List {
            ForEach(sections, id: \.category) { section in
                Section {
                    ForEach(section.programs) { program in
                        CLIProgramRow(
                            program: program,
                            size: sizes[program.url],
                            isSelected: selectedURLs.contains(program.url),
                            onToggle: { toggle(program.url) },
                            onInfo: { detailProgram = program }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                } header: {
                    HStack {
                        Text(section.category.title)
                        Spacer()
                        Text(StorageFormatting.bytes(sectionBytes(section.programs)))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: filteredPrograms.count)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No CLI programs to clean",
            message: emptyStateMessage,
            systemImage: "checkmark.seal.fill",
            tint: AppTheme.mint,
            actionTitle: "Scan Again",
            action: onScan
        )
        .frame(minHeight: 430)
    }

    private var loadingState: some View {
        ScanningLoaderView(
            title: "Reading installed programs",
            subtitle: "Discovering Homebrew, version managers, global npm packages, and standalone binaries.",
            progress: nil,
            scanners: [
                ScannerLoaderItem(
                    id: "cli-discovery",
                    title: "Installed programs",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Reading brew, fnm, nvm, and binary paths",
                    systemImage: "terminal.fill",
                    tint: AppTheme.teal
                ),
                ScannerLoaderItem(
                    id: "cli-sizing",
                    title: "On-disk sizes",
                    state: .pending,
                    itemsScanned: 0,
                    message: "Measuring after discovery",
                    systemImage: "internaldrive",
                    tint: .secondary
                )
            ],
            cancelAction: cancelLoading
        )
    }

}

// MARK: - Helpers

private extension CLIProgramsView {
    /// Stable identity for the loading task so it re-runs when the scanned roots change.
    var rootsKey: String {
        findings.flatMap(\.filePaths).map(\.path).sorted().joined(separator: "|")
    }

    var deletionFinding: StorageFinding {
        StorageFinding(
            kind: findings.first?.kind ?? .cliApps,
            domain: findings.first?.domain ?? .cliTooling,
            bytes: selectedBytes,
            itemCount: selectedURLs.count,
            safety: .review,
            examples: [],
            filePaths: Array(selectedURLs)
        )
    }

    func sectionBytes(_ programs: [CLIProgram]) -> Int64 {
        programs.reduce(Int64(0)) { $0 + (sizes[$1.url] ?? 0) }
    }

    func sorted(_ programs: [CLIProgram]) -> [CLIProgram] {
        switch sortOption {
        case .sizeDesc:
            programs.sorted { (sizes[$0.url] ?? 0) > (sizes[$1.url] ?? 0) }
        case .nameAsc:
            programs.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    func toggleAllVisible() {
        if allVisibleSelected {
            for program in filteredPrograms { selectedURLs.remove(program.url) }
        } else {
            for program in filteredPrograms { selectedURLs.insert(program.url) }
        }
    }

    /// Two-phase load: first discover and publish the program list so it appears
    /// immediately, then size each program in the background. Sizing hundreds of
    /// global packages can take a moment, so it must not block the list.
    func load() async {
        isLoading = true
        sizes = [:]

        // Phase 1 — discover programs directly from disk (Homebrew, version
        // managers, global Node packages, and standalone installer binaries),
        // independent of whether a storage scan has run.
        let discovered = await Task.detached(priority: .userInitiated) {
            CLIProgramCatalog.discoverInstalled()
        }.value

        guard !Task.isCancelled else { return }
        programs = discovered
        isLoading = false

        // Phase 2 — measure on-disk sizes.
        let urls = discovered.map(\.url)
        let measured = await Task.detached(priority: .utility) {
            var sizes: [URL: Int64] = [:]
            for url in urls {
                if Task.isCancelled { break }
                sizes[url] = StorageFormatting.itemSize(at: url)
            }
            return sizes
        }.value

        guard !Task.isCancelled else { return }
        sizes = measured
        loadTask = nil
    }

    func startLoading() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}
