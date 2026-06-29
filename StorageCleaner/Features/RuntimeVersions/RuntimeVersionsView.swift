import SwiftUI

/// Lists runtimes that have multiple versions installed and lets the user reclaim space by
/// removing older ones. The newest version of each runtime is always suggested as "keep"; older
/// versions are pre-selected as a suggestion the user can freely override before confirming.
///
/// Discovery is live (independent of a storage scan) and two-phase — the grouped list appears
/// immediately, then on-disk sizes fill in — mirroring `CLIProgramsView`.
struct RuntimeVersionsView: View {
    let onRemove: ([URL]) async -> Void
    let permissionHandler: (any StoragePermissionHandling)?
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var groups: [RuntimeVersionGroup] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var loadTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var itemsByURL: [URL: RuntimeVersionItem] {
        Dictionary(groups.flatMap(\.items).map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var totalReclaimable: Int64 {
        groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
    }

    private var selectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { $0 + (itemsByURL[$1]?.bytes ?? 0) }
    }

    var body: some View {
        Group {
            if isLoading && groups.isEmpty {
                loadingState
            } else if groups.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Runtime Versions")
        .navigationSubtitle(subtitle)
        .accessibilityIdentifier("runtime-versions-root")
        .toolbar { toolbarContent }
        .onAppear { startLoading() }
        .onDisappear { cancelLoading() }
        .sheet(isPresented: $showDeleteConfirmation) {
            DeleteConfirmationSheet(
                selectedURLs: Array(selectedURLs),
                totalBytes: selectedBytes,
                onDelete: {
                    let urls = Array(selectedURLs)
                    selectedURLs.removeAll()
                    showDeleteConfirmation = false
                    Task {
                        await onRemove(urls)
                        startLoading()
                    }
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
    }

    private var subtitle: String {
        let runtimes = groups.count
        return "\(runtimes) runtime\(runtimes == 1 ? "" : "s") with multiple versions · "
            + "\(StorageFormatting.bytes(totalReclaimable)) reclaimable"
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !selectedURLs.isEmpty {
                Button {
                    requestDeleteConfirmation()
                } label: {
                    Label("Remove \(selectedURLs.count)", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .help("Remove \(selectedURLs.count) older versions")
            }
        }

        ToolbarItem {
            Button {
                startLoading()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .help("Look for installed versions again")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectionBar
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(groups) { group in
                        RuntimeVersionGroupCard(
                            group: group,
                            selectedURLs: selectedURLs,
                            onToggle: toggle,
                            onToggleAllOlder: { toggleAllOlder(in: group) }
                        )
                    }
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.violet.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Runtime Versions")
                    .font(.title2.weight(.semibold))
                Text("Older language runtimes and SDKs kept by your version managers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormatting.bytes(totalReclaimable))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("reclaimable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("Newest version of each runtime is kept. Select older versions to remove.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !selectedURLs.isEmpty {
                Text("\(selectedURLs.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())
                Text(StorageFormatting.bytes(selectedBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedURLs.count)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No Duplicate Versions",
            message: "Every language runtime has a single installed version. When you keep multiple "
                + "versions of tools like Node, Python, Go, .NET, Rust, PHP, or a JDK, the older "
                + "ones show up here.",
            systemImage: "square.stack.3d.up",
            tint: AppTheme.violet,
            actionTitle: "Rescan",
            action: startLoading
        )
        .frame(minHeight: 430)
    }

    private var loadingState: some View {
        ScanningLoaderView(
            title: "Looking for runtime versions",
            subtitle: "Discovering every tool with multiple installed versions, then measuring on-disk sizes.",
            progress: nil,
            scanners: [
                ScannerLoaderItem(
                    id: "runtime-discovery",
                    title: "Version managers",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "asdf, mise, fnm, pyenv, rbenv, nvm, sdkman",
                    systemImage: "square.stack.3d.up.fill",
                    tint: AppTheme.violet
                ),
                ScannerLoaderItem(
                    id: "runtime-sizing",
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

// MARK: - Behaviour

private extension RuntimeVersionsView {
    func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }

    func toggleAllOlder(in group: RuntimeVersionGroup) {
        guard !group.source.requiresManualRemoval else { return }
        let older = group.olderItems.map(\.url)
        if older.allSatisfy(selectedURLs.contains) {
            older.forEach { selectedURLs.remove($0) }
        } else {
            older.forEach { selectedURLs.insert($0) }
        }
    }

    func requestDeleteConfirmation() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        showDeleteConfirmation = true
    }

    /// Two-phase load: discover groups (fast) then measure on-disk sizes in the background.
    /// Older, removable versions are pre-selected as the suggested cleanup.
    func load() async {
        isLoading = true
        let access = permissionHandler?.beginHomeFolderAccess()
        defer { access?.stop() }

        let discovered = await Task.detached(priority: .userInitiated) {
            RuntimeVersionCatalog.discoverGroups()
        }.value

        guard !Task.isCancelled else { return }
        groups = discovered
        isLoading = false
        selectedURLs = suggestedSelection(in: discovered)

        let measured = await Task.detached(priority: .utility) {
            RuntimeVersionCatalog.measured(discovered)
        }.value

        guard !Task.isCancelled else { return }
        groups = measured
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

    func suggestedSelection(in groups: [RuntimeVersionGroup]) -> Set<URL> {
        Set(groups.flatMap { group in
            group.source.requiresManualRemoval ? [] : group.olderItems.map(\.url)
        })
    }
}
