import SwiftUI

/// Embedded "Runtime Versions" card shown inside Developer Storage.
///
/// Discovers installed runtimes with multiple versions and measures on-disk sizes in the
/// background, then renders one card per runtime (newest version marked as keep, older ones
/// selectable for removal). The newest version of each runtime is always suggested as
/// "keep"; older versions are pre-selected as a suggestion the user can freely override
/// before confirming.
///
/// The detail-route version of this surface lives in ``RuntimeVersionsView`` and shares
/// the same group row/header primitives.
struct RuntimeVersionsSection: View {
    let onRemove: ([URL]) async -> Void
    let permissionHandler: (any StoragePermissionHandling)?
    var canUseProActions = true
    var onRequirePro: () -> Void = {}

    @State private var groups: [RuntimeVersionGroup] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isLoading && groups.isEmpty {
                loadingState
            } else if groups.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .task { await load() }
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
                        await load()
                    }
                },
                onCancel: { showDeleteConfirmation = false }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.violet.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Runtime Versions")
                    .font(.headline)
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !isLoading || !groups.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(StorageFormatting.bytes(totalReclaimable))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                    Text("reclaimable")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !selectedURLs.isEmpty {
                Button {
                    requestDeleteConfirmation()
                } label: {
                    Label("Remove \(selectedURLs.count)", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
            } else {
                Button {
                    Task { await load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Look for installed versions again")
                .accessibilityLabel("Rescan runtime versions")
            }
        }
        .padding(16)
    }

    private var headerSubtitle: String {
        if isLoading && groups.isEmpty {
            return "Discovering installed versions…"
        }
        if groups.isEmpty {
            return "No runtime has multiple installed versions"
        }
        let runtimes = groups.count
        return "\(runtimes) runtime\(runtimes == 1 ? "" : "s") with multiple versions · "
            + "newest of each is kept"
    }

    private var content: some View {
        VStack(spacing: 0) {
            selectionBar
            VStack(spacing: 12) {
                ForEach(groups) { group in
                    RuntimeVersionGroupCard(
                        group: group,
                        selectedURLs: selectedURLs,
                        onToggle: toggle,
                        onToggleAllOlder: { toggleAllOlder(in: group) }
                    )
                }
            }
            .padding(16)
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedURLs.count)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AppTheme.mint)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No duplicate versions")
                    .font(.subheadline.weight(.medium))
                Text(
                    "Every installed runtime has a single version. Install a second version of " +
                    "Node, Python, Go, .NET, Rust, PHP, or a JDK to see it here."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
            Text("Looking for installed runtime versions…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Behaviour

private extension RuntimeVersionsSection {
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
    }

    func suggestedSelection(in groups: [RuntimeVersionGroup]) -> Set<URL> {
        Set(groups.flatMap { group in
            group.source.requiresManualRemoval ? [] : group.olderItems.map(\.url)
        })
    }
}
