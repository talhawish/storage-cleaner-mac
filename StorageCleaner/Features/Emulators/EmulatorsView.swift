import SwiftUI

/// Lists installed simulator/emulator OS images (Apple runtimes + Android system images) with their
/// sizes and lets the user reclaim space by removing the ones they don't need. Self-contained and
/// driven by live discovery, like `AppsView` — no scan required.
///
/// Nothing is pre-selected: removing an OS image is consequential, so every selection is explicit.
struct EmulatorsView: View {
    private let service: EmulatorManagementService

    @State private var images: [EmulatorImage] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isLoading = true
    @State private var showConfirmation = false
    @State private var loadTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(service: EmulatorManagementService = .live) {
        self.service = service
    }

    private var sections: [(platform: EmulatorPlatform, images: [EmulatorImage])] {
        EmulatorPlatform.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .compactMap { platform in
                let matching = images.filter { $0.platform == platform }
                return matching.isEmpty ? nil : (platform, matching)
            }
    }

    private var selectedImages: [EmulatorImage] {
        images.filter { selectedIDs.contains($0.id) }
    }

    private var totalBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }
    private var selectedBytes: Int64 { selectedImages.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        Group {
            if isLoading && images.isEmpty {
                loadingState
            } else if images.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Simulators & Emulators")
        .navigationSubtitle("\(images.count) OS images · \(StorageFormatting.bytes(totalBytes))")
        .accessibilityIdentifier("simulators-emulators-root")
        .toolbar { toolbarContent }
        .onAppear { startLoading() }
        .onDisappear { cancelLoading() }
        .sheet(isPresented: $showConfirmation) {
            EmulatorDeleteConfirmationSheet(
                images: selectedImages,
                onConfirm: {
                    let toRemove = selectedImages
                    selectedIDs.removeAll()
                    showConfirmation = false
                    Task {
                        _ = await service.remove(toRemove)
                        startLoading()
                    }
                },
                onCancel: { showConfirmation = false }
            )
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !selectedIDs.isEmpty {
                Button {
                    showConfirmation = true
                } label: {
                    Label("Remove \(selectedIDs.count)", systemImage: "externaldrive.badge.minus")
                }
                .foregroundStyle(.red)
                .help("Remove \(selectedIDs.count) selected OS images")
            }
        }

        ToolbarItem {
            Button {
                startLoading()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .help("Look for installed OS images again")
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectionBar
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(sections, id: \.platform) { section in
                        EmulatorSectionCard(
                            platform: section.platform,
                            images: section.images,
                            selectedIDs: selectedIDs,
                            onToggle: toggle,
                            onToggleAll: { toggleAll(in: section.images) }
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
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "iphone.gen3")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Simulators & Emulators")
                    .font(.title2.weight(.semibold))
                Text("Installed iOS simulator runtimes and Android system images — often several GB each")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormatting.bytes(totalBytes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("Select the OS images you no longer need. Nothing is removed until you confirm.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !selectedIDs.isEmpty {
                Text("\(selectedIDs.count) selected")
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
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedIDs.count)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No Simulator or Emulator Images",
            message: "Installed iOS simulator runtimes and Android system images appear here so you can "
                + "reclaim the space they use. None were found on this Mac.",
            systemImage: "iphone.gen3",
            tint: AppTheme.accent,
            actionTitle: "Rescan",
            action: startLoading
        )
        .frame(minHeight: 430)
    }

    private var loadingState: some View {
        ScanningLoaderView(
            title: "Looking for OS images",
            subtitle: "Discovering installed iOS simulator runtimes and Android system images.",
            progress: nil,
            scanners: [
                ScannerLoaderItem(
                    id: "apple-runtimes",
                    title: "Apple simulator runtimes",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Reading Xcode CoreSimulator devices",
                    systemImage: "iphone.gen3",
                    tint: AppTheme.accent
                ),
                ScannerLoaderItem(
                    id: "android-images",
                    title: "Android system images",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Scanning ~/.android/avd",
                    systemImage: "ipad.gen2",
                    tint: AppTheme.violet
                )
            ],
            cancelAction: cancelLoading
        )
    }
}

// MARK: - Behaviour

private extension EmulatorsView {
    func toggle(_ image: EmulatorImage) {
        guard image.isRemovable else { return }
        if selectedIDs.contains(image.id) {
            selectedIDs.remove(image.id)
        } else {
            selectedIDs.insert(image.id)
        }
    }

    func toggleAll(in images: [EmulatorImage]) {
        let removable = images.filter(\.isRemovable).map(\.id)
        if removable.allSatisfy(selectedIDs.contains) {
            removable.forEach { selectedIDs.remove($0) }
        } else {
            removable.forEach { selectedIDs.insert($0) }
        }
    }

    /// Two-phase load: discover the images (Apple sizes are instant) so the list appears immediately,
    /// then measure Android image sizes in the background.
    func load() async {
        isLoading = true
        let discovered = await service.discover()
        guard !Task.isCancelled else { return }
        images = discovered
        isLoading = false
        // Drop selections that no longer exist (e.g. after a removal + reload).
        selectedIDs = selectedIDs.intersection(Set(discovered.map(\.id)))

        let sized = await Task.detached(priority: .utility) { [service] in
            service.measuringAndroidSizes(in: discovered)
        }.value
        guard !Task.isCancelled else { return }
        images = sized
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
