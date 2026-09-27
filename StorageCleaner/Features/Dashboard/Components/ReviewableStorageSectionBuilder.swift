import SwiftUI

/// Shared phase routing for categories whose findings must be reviewed by the user.
extension AppShellView {
    @ViewBuilder
    func reviewableStorageView(
        title: String,
        kinds: [StorageFindingKind],
        subtitle: String,
        emptyMessage: String
    ) -> some View {
        let allFindings = (viewModel.snapshot?.findings ?? []).filter { kinds.contains($0.kind) }
        let findings = filteredFindings(for: kinds)
        let reviewItemsAreHidden = !showReviewItems && findings.isEmpty && !allFindings.isEmpty
        let scanAction = { viewModel.startScan(for: kinds) }
        let initialState = reviewableInitialState(title: title, subtitle: subtitle, kinds: kinds, action: scanAction)
        let emptyState = reviewableEmptyState(title: title, message: emptyMessage, action: scanAction)
        let hiddenItemsState = reviewableStorageHiddenItemsState(action: { showReviewItems = true })

        switch viewModel.phase {
        case .scanning:
            reviewableScanProgress(title: title, subtitle: subtitle, kinds: kinds)
        case .permissionRequired:
            reviewablePermissionView()
        case let .failed(message):
            ErrorStateView(message: message, retry: scanAction)
                .padding(28)
        case .idle:
            initialState.padding(28)
        case .empty:
            reviewableScannedState(
                kinds: kinds,
                reviewItemsAreHidden: reviewItemsAreHidden,
                initial: initialState,
                empty: emptyState,
                hidden: hiddenItemsState
            )
        case .results where !viewModel.hasScanned(kinds):
            initialState.padding(28)
        case .results where findings.isEmpty:
            reviewableScannedState(
                kinds: kinds,
                reviewItemsAreHidden: reviewItemsAreHidden,
                initial: initialState,
                empty: emptyState,
                hidden: hiddenItemsState
            )
        case .results:
            StorageFindingsView(
                title: title,
                findings: findings,
                onScan: scanAction,
                onOpenFinding: openFinding
            )
        }
    }

    private func reviewableScanProgress(
        title: String,
        subtitle: String,
        kinds: [StorageFindingKind]
    ) -> some View {
        ScanProgressView(
            viewModel: viewModel,
            title: "Scanning \(title)",
            subtitle: subtitle,
            visibleScannerKinds: Set(kinds)
        )
        .padding(28)
    }

    private func reviewablePermissionView() -> some View {
        PermissionRequiredView(
            blockedPermissions: viewModel.blockedPermissions,
            onOpenSettings: viewModel.openSystemSettings,
            onGrantAccess: viewModel.grantHomeFolderAccess
        )
        .padding(28)
    }

    private func reviewableInitialState(
        title: String,
        subtitle: String,
        kinds: [StorageFindingKind],
        action: @escaping () -> Void
    ) -> some View {
        reviewableStorageInitialState(
            title: "Find \(title.lowercased())",
            subtitle: subtitle + " Unfamiliar data is always review-only.",
            actionTitle: "Scan \(title)",
            systemImage: kinds.contains(.localAIModels) ? "sparkles" : "folder.badge.questionmark",
            action: action
        )
    }

    private func reviewableEmptyState(
        title: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        reviewableStorageEmptyState(
            title: "No matching items in \(title)",
            message: message + " Only accessible locations are included.",
            action: action
        )
    }

    @ViewBuilder
    private func reviewableScannedState<Initial: View, Empty: View, Hidden: View>(
        kinds: [StorageFindingKind],
        reviewItemsAreHidden: Bool,
        initial: Initial,
        empty: Empty,
        hidden: Hidden
    ) -> some View {
        if reviewItemsAreHidden {
            hidden.padding(28)
        } else {
            reviewableEmptyOrInitialState(kinds: kinds, initial: initial, empty: empty)
        }
    }

    private func reviewableEmptyOrInitialState<Initial: View, Empty: View>(
        kinds: [StorageFindingKind],
        initial: Initial,
        empty: Empty
    ) -> some View {
        scannedSectionState(
            kinds: kinds,
            initial: { initial },
            empty: { empty }
        )
        .padding(28)
    }
}
