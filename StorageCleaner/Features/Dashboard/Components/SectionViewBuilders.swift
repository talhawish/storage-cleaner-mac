import SwiftUI

/// Per-section content routing for `AppShellView`. Each section is a
/// `switch viewModel.phase` that returns the right view for the current scan
/// state: scanning progress, permission gate, error, pre-scan hero
/// (`InitialStateView`), post-scan empty (`EmptyStateView`), or the
/// feature view itself.
///
/// Extracted to keep `AppShellView` under the 500-line SwiftLint warn
/// threshold while leaving a single, readable home for the per-section
/// phase logic.
extension AppShellView {
    @ViewBuilder
    func developerStorageView() -> some View {
        let kinds = DeveloperDomains.kinds
        let findings = viewModel.snapshot?.findings ?? []
        let sectionFindings = findings.filter { kinds.contains($0.kind) }
        let scanAction = { viewModel.startScan(for: kinds) }
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Developer Storage",
                subtitle: "Only developer storage locations are being scanned.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: scanAction)
                .padding(28)
        case .idle:
            developerStorageInitialState(action: scanAction)
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { developerStorageInitialState(action: scanAction) },
                empty: { developerStorageEmptyState(action: scanAction) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { developerStorageInitialState(action: scanAction) },
                empty: { developerStorageEmptyState(action: scanAction) }
            )
            .padding(28)
        case .results:
            developerStorageResults(
                findings: sectionFindings,
                kinds: kinds
            )
        }
    }

    @ViewBuilder
    private func developerStorageResults(
        findings: [StorageFinding],
        kinds: [StorageFindingKind]
    ) -> some View {
        DeveloperStorageView(
            findings: findings,
            onScan: {
                resetDetailNavigation()
                viewModel.startScan(for: kinds)
            },
            onDelete: { urls in
                Task { await viewModel.deleteFiles(urls) }
            },
            onOpenFinding: openFinding,
            onRemoveRuntimeVersions: { urls in
                _ = await viewModel.removeRuntimeVersions(urls)
            }
        )
    }

    @ViewBuilder
    func largeFilesView(kinds: [StorageFindingKind]) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Large Files",
                subtitle: "Only large-file locations are being scanned.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle:
            largeFilesInitialState(action: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { largeFilesInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { largeFilesEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { largeFilesInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { largeFilesEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results:
            LargeFilesView(
                findings: sectionFindings,
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    func leftoversView(kinds: [StorageFindingKind]) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning Leftovers",
                subtitle: "Only leftover-installer locations are being scanned.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle:
            leftoversInitialState(action: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { leftoversInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { leftoversEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { leftoversInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { leftoversEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results:
            LeftoversView(
                findings: sectionFindings,
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    func systemJunkView(kinds: [StorageFindingKind]) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning System Junk",
                subtitle: "Comparing user Library entries against installed apps.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle:
            systemJunkInitialState(action: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { systemJunkInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { systemJunkEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { systemJunkInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { systemJunkEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results:
            SystemJunkView(
                findings: sectionFindings,
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    func mediaCategoryView(title: String, kinds: [StorageFindingKind], emptyStateMessage: String) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        let scanAction = { viewModel.startScan(for: kinds) }
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning \(title)",
                subtitle: "Only this category is being scanned.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: scanAction)
                .padding(28)
        case .idle:
            mediaCategoryInitialState(title: title, action: scanAction)
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { mediaCategoryInitialState(title: title, action: scanAction) },
                empty: { mediaCategoryEmptyState(title: title, message: emptyStateMessage, action: scanAction) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { mediaCategoryInitialState(title: title, action: scanAction) },
                empty: { mediaCategoryEmptyState(title: title, message: emptyStateMessage, action: scanAction) }
            )
            .padding(28)
        case .results:
            MediaCategoryView(
                title: title,
                findings: sectionFindings,
                emptyStateMessage: emptyStateMessage,
                onScan: scanAction,
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    func duplicatesView(kinds: [StorageFindingKind]) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning for Duplicates",
                subtitle: "Comparing media by content to find byte-identical copies.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .idle:
            duplicatesInitialState(action: { viewModel.startScan(for: kinds) })
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { duplicatesInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { duplicatesEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { duplicatesInitialState(action: { viewModel.startScan(for: kinds) }) },
                empty: { duplicatesEmptyState(action: { viewModel.startScan(for: kinds) }) }
            )
            .padding(28)
        case .results:
            DuplicatesView(
                findings: sectionFindings,
                onScan: { viewModel.startScan(for: kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    @ViewBuilder
    func cliProgramsView(kinds: [StorageFindingKind], emptyStateMessage: String) -> some View {
        let sectionFindings = filteredFindings(for: kinds)
        let scanAction = { viewModel.startScan(for: kinds) }
        switch viewModel.phase {
        case .scanning:
            ScanProgressView(
                viewModel: viewModel,
                title: "Scanning CLI Programs",
                subtitle: "Only command-line tool locations are being scanned.",
                visibleScannerKinds: Set(kinds)
            )
            .padding(28)
        case .permissionRequired:
            PermissionRequiredView(
                blockedPermissions: viewModel.blockedPermissions,
                onOpenSettings: viewModel.openSystemSettings,
                onRetry: viewModel.retryAfterPermission
            )
            .padding(28)
        case let .failed(message):
            ErrorStateView(message: message, retry: scanAction)
                .padding(28)
        case .idle:
            cliProgramsInitialState(message: emptyStateMessage, action: scanAction)
                .padding(28)
        case .empty:
            scannedSectionState(
                kinds: kinds,
                initial: { cliProgramsInitialState(message: emptyStateMessage, action: scanAction) },
                empty: { cliProgramsEmptyState(message: emptyStateMessage, action: scanAction) }
            )
            .padding(28)
        case .results where sectionFindings.isEmpty:
            scannedSectionState(
                kinds: kinds,
                initial: { cliProgramsInitialState(message: emptyStateMessage, action: scanAction) },
                empty: { cliProgramsEmptyState(message: emptyStateMessage, action: scanAction) }
            )
            .padding(28)
        case .results:
            CLIProgramsView(
                findings: sectionFindings,
                emptyStateMessage: emptyStateMessage,
                onScan: scanAction,
                onRemove: { urls in _ = await viewModel.removeCLIPrograms(urls) }
            )
        }
    }

    @ViewBuilder
    func findingDestination(for finding: StorageFinding) -> some View {
        if finding.kind == .duplicatePhotos
            || finding.kind == .duplicateVideos
            || finding.kind == .duplicateDocuments {
            DuplicatesView(
                findings: [finding],
                onScan: { viewModel.startScan(for: DuplicateMediaFilter.all.kinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        } else if finding.kind == .dockerArtifacts {
            DockerView(onDockerChanged: {
                viewModel.startScan(for: [.dockerArtifacts])
            })
        } else if finding.kind == .cliApps {
            CLIProgramsView(
                findings: [finding],
                emptyStateMessage: "Homebrew, version managers, global npm packages, "
                    + "and standalone CLI tools you've installed.",
                onScan: { viewModel.startScan(for: [.cliApps]) },
                onRemove: { urls in _ = await viewModel.removeCLIPrograms(urls) }
            )
        } else if finding.kind == .runtimeVersions {
            RuntimeVersionsView(
                onRemove: { urls in _ = await viewModel.removeRuntimeVersions(urls) }
            )
        } else if AppSection.leftovers.filterKinds.contains(finding.kind) {
            LeftoversView(
                findings: filteredFindings(for: AppSection.leftovers.filterKinds),
                onScan: { viewModel.startScan(for: AppSection.leftovers.filterKinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        } else if AppSection.systemJunk.filterKinds.contains(finding.kind) {
            SystemJunkView(
                findings: filteredFindings(for: AppSection.systemJunk.filterKinds),
                onScan: { viewModel.startScan(for: AppSection.systemJunk.filterKinds) },
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        } else {
            CategoryDetailView(
                finding: finding,
                onDelete: { urls in
                    Task { await viewModel.deleteFiles(urls) }
                }
            )
        }
    }

    func filteredFindings(for kinds: [StorageFindingKind]) -> [StorageFinding] {
        guard !kinds.isEmpty else { return [] }
        return (viewModel.snapshot?.findings ?? []).filter { kinds.contains($0.kind) }
    }

    func openFinding(_ finding: StorageFinding) {
        route(to: finding)
        viewModel.selectedFinding = finding
    }

    func route(to finding: StorageFinding) {
        detailPath = NavigationPath()
        detailPath.append(finding)
    }

    func resetDetailNavigation() {
        detailPath = NavigationPath()
        viewModel.selectedFinding = nil
    }

    /// Picks the right post-scan view for a section. When the section's
    /// kinds have no findings but the last scan covered them, the user has
    /// actually scanned and got nothing — show the calm empty state. When
    /// the last scan did not touch this section, the user has not scanned
    /// it yet — show the welcoming initial state. Without this split, a
    /// targeted scan of one section makes every other section look "empty"
    /// even though the user has never asked for it to be scanned.
    @ViewBuilder
    func scannedSectionState<Initial: View, Empty: View>(
        kinds: [StorageFindingKind],
        initial: () -> Initial,
        empty: () -> Empty
    ) -> some View {
        if viewModel.hasScanned(kinds) {
            empty()
        } else {
            initial()
        }
    }
}
