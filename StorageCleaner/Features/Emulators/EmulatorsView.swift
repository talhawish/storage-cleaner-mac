import SwiftUI

/// Lists installed simulator/emulator OS images (Apple runtimes + Apple Device Support debug
/// symbols + CoreSimulator device instances + Android system images) with their sizes and lets
/// the user reclaim space by removing the ones they don't need. Self-contained and driven by
/// live discovery, like `AppsView` — no scan required.
///
/// All state lives in ``EmulatorsViewModel`` so the loading / empty / content state machine,
/// the Rescan button, and the live-factory wiring can be unit-tested without a SwiftUI host.
struct EmulatorsView: View {
    var canUseProActions = true
    var onRequirePro: () -> Void = {}
    var onCleanupComplete: (EmulatorCleanupResult, [EmulatorImage]) async -> Void = { _, _ in }

    @State private var viewModel: EmulatorsViewModel
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        viewModel: EmulatorsViewModel = EmulatorsViewModel(),
        canUseProActions: Bool = true,
        onRequirePro: @escaping () -> Void = {},
        onCleanupComplete: @escaping (EmulatorCleanupResult, [EmulatorImage]) async -> Void = { _, _ in }
    ) {
        self.canUseProActions = canUseProActions
        self.onRequirePro = onRequirePro
        self.onCleanupComplete = onCleanupComplete
        viewModel.canDelete = { canUseProActions }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            switch viewModel.state {
            case .loading:
                loadingState
            case .empty:
                emptyState
            case .loaded:
                content
            case .permissionRequired:
                PermissionRequiredView(
                    blockedPermissions: viewModel.blockedPermissions,
                    onOpenSettings: viewModel.openSystemSettings,
                    onGrantAccess: viewModel.grantAccessAndRetry
                )
            case let .failed(message):
                ErrorStateView(message: message, retry: { viewModel.start() })
                    .padding(28)
            }
        }
        .navigationTitle("Simulators & Emulators")
        .navigationSubtitle("\(viewModel.images.count) items · \(StorageFormatting.bytes(viewModel.totalBytes))")
        .accessibilityIdentifier("simulators-emulators-root")
        .toolbar { toolbarContent }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.cancel() }
        .sheet(isPresented: $viewModel.showConfirmation) {
            EmulatorDeleteConfirmationSheet(
                images: viewModel.selectedImages,
                onConfirm: performDeletion,
                onCancel: { viewModel.showConfirmation = false }
            )
        }
        .alert("Some Items Couldn’t Be Removed", isPresented: $viewModel.showCleanupFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.cleanupFailureMessage ?? "The selected items could not be removed.")
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !viewModel.selectedIDs.isEmpty {
                Button {
                    requestDeleteConfirmation()
                } label: {
                    Label("Remove \(viewModel.selectedIDs.count)", systemImage: "externaldrive.badge.minus")
                }
                .foregroundStyle(.red)
                .help("Remove \(viewModel.selectedIDs.count) selected OS images")
                .accessibilityHint("Asks for confirmation, then removes the selected OS images. "
                    + "Apple runtimes can be re-downloaded; other items move to the Trash")
                .disabled(viewModel.isDeleting)
            }
        }

        ToolbarItem {
            Button {
                viewModel.start()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])
            .help("Look for installed OS images again")
            .disabled(viewModel.isDeleting)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectionBar
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.sections, id: \.platform) { section in
                        EmulatorSectionCard(
                            platform: section.platform,
                            images: section.images,
                            selectedIDs: viewModel.selectedIDs,
                            onToggle: viewModel.toggle,
                            onToggleAll: { viewModel.toggleAll(in: section.images) }
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
                RoundedRectangle(cornerRadius: AppTheme.Radius.large, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: "iphone.gen3")
                    .font(AppTheme.Typography.heroIcon)
                    .foregroundStyle(AppTheme.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Simulators & Emulators")
                    .font(.title2.weight(.semibold))
                Text("Apple simulator runtimes, device debug symbols, simulator device instances, "
                    + "and Android system images — often several GB each")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(StorageFormatting.bytes(viewModel.totalBytes))
                    .font(AppTheme.Typography.statValue)
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

            if !viewModel.selectedIDs.isEmpty {
                Text("\(viewModel.selectedIDs.count) selected")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                    .contentTransition(.numericText())
                Text(StorageFormatting.bytes(viewModel.selectedBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if viewModel.isDeleting {
                ProgressView()
                    .controlSize(.small)
                Text("Removing…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: viewModel.selectedIDs.count)
    }

    private var emptyState: some View {
        EmptyStateView(
            title: "No Simulator or Emulator Images",
            message: "Installed iOS / tvOS / watchOS / visionOS simulator runtimes, device debug "
                + "symbols, simulator device instances, and Android system images appear here so "
                + "you can reclaim the space they use. None were found on this Mac.",
            systemImage: "iphone.gen3",
            tint: AppTheme.accent,
            actionTitle: "Rescan",
            action: { viewModel.start() }
        )
        .frame(minHeight: 430)
    }

    private var loadingState: some View {
        ScanningLoaderView(
            title: "Looking for OS images",
            subtitle: "Discovering installed iOS / tvOS / watchOS / visionOS simulator runtimes, "
                + "device debug symbols, simulator device instances, and Android system images.",
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
                    id: "ios-device-support",
                    title: "iOS Device Support",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Reading ~/Library/Developer/Xcode",
                    systemImage: "ladybug.fill",
                    tint: AppTheme.violet
                ),
                ScannerLoaderItem(
                    id: "simulator-devices",
                    title: "Simulator device instances",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Walking CoreSimulator/Devices",
                    systemImage: "ipad.gen2",
                    tint: AppTheme.indigo
                ),
                ScannerLoaderItem(
                    id: "android-images",
                    title: "Android system images",
                    state: .scanning,
                    itemsScanned: 0,
                    message: "Scanning ~/Library/Android/sdk/system-images",
                    systemImage: "smartphone",
                    tint: AppTheme.mint
                )
            ],
            cancelAction: { viewModel.cancel() }
        )
    }

    private func requestDeleteConfirmation() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        viewModel.showConfirmation = true
    }

    private func performDeletion() {
        let toRemove = viewModel.selectedImages
        viewModel.showConfirmation = false
        Task {
            let result = await viewModel.delete(toRemove)
            await onCleanupComplete(result, toRemove)
            if !result.removedIDs.isEmpty {
                viewModel.refreshAfterRemoval()
            }
        }
    }
}
