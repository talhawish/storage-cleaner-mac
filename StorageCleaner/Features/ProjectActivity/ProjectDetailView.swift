import SwiftUI

struct ProjectDetailView: View {
    enum Action: Hashable, Identifiable {
        case hibernate
        case compress

        var id: Self { self }
    }

    let project: ProjectInfo
    let onHibernate: (ProjectInfo) async -> HibernationOutcome
    let onCompress: (ProjectInfo) async -> CompressionOutcome
    var canUseProActions = true
    var onRequirePro: () -> Void = {}
    var permissionHandler: (any StoragePermissionHandling)?

    @State private var pendingAction: Action?
    @State private var isHibernating = false
    @State private var isCompressing = false
    @State private var hibernationError: String?
    @State private var compressionOutcome: CompressionOutcome?
    @State private var showCompressionSuccess = false

    var body: some View {
        AppModal(
            idealWidth: 760,
            minHeight: 520,
            idealHeight: 600,
            maxHeight: 760
        ) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: project.iconFallback.symbolName,
                    iconTint: Color(hex: project.iconFallback.color),
                    title: project.name,
                    subtitle: "\(project.iconFallback.rawValue) · \(project.activityStatus.label)",
                    trailing: .sizeBadge(
                        value: StorageFormatting.bytes(project.totalSize),
                        tint: AppTheme.accent
                    ),
                    showsCloseButton: true,
                    accessibilityIdentifier: "project-detail-header"
                )

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        activityBanner
                        gitSection
                        sizeBreakdown
                        technologyInfo
                        locationInfo
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }

                Divider()

                AppModalActionBar(
                    cancel: nil,
                    actions: [
                        AppModalActionBar.Action(
                            title: "Show in Finder",
                            systemImage: canUseProActions ? "folder" : "lock.fill",
                            tint: AppTheme.accent,
                            isIconOnly: true,
                            help: canUseProActions
                                ? "Show the project in Finder"
                                : "Requires Pro to show in Finder",
                            action: { revealInFinder() }
                        ),
                        AppModalActionBar.Action(
                            title: canUseProActions ? "Hibernate" : "Hibernate (Pro)",
                            systemImage: canUseProActions ? "archivebox.fill" : "lock.fill",
                            tint: AppTheme.orange,
                            isDisabled: project.dependencySize == 0 || isHibernating || isCompressing,
                            help: actionHelp(
                                unlocked: "Move regenerable dependencies to the Trash, keeping your source."
                            ),
                            action: { requestAction(.hibernate) }
                        ),
                        AppModalActionBar.Action(
                            title: canUseProActions ? "Hibernate & Compress" : "Hibernate & Compress (Pro)",
                            systemImage: canUseProActions ? "doc.zipper" : "lock.fill",
                            tint: project.activityStatus == .abandoned ? .red : AppTheme.accent,
                            isProminent: true,
                            isDisabled: project.dependencySize == 0 || isHibernating || isCompressing,
                            isDefault: true,
                            help: actionHelp(
                                unlocked: "Move dependencies to Trash, compress the project, "
                                    + "then move the folder to Trash."
                            ),
                            action: { requestAction(.compress) }
                        )
                    ],
                    isProcessing: isHibernating || isCompressing,
                    style: .compact
                )
            }
        }
        .sheet(item: hibernateConfirmationBinding) { _ in
            ConfirmationModal(
                variant: .warning,
                title: "Hibernate this project?",
                message: hibernateMessage,
                iconSystemName: "archivebox.fill",
                iconTint: AppTheme.orange,
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Move Dependencies to Trash",
                    systemImage: "archivebox.fill",
                    isProminent: true,
                    isDefault: true,
                    action: hibernateProject
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
        .sheet(item: compressConfirmationBinding) { _ in
            ConfirmationModal(
                variant: .destructive,
                title: "Hibernate & Compress this project?",
                message: compressMessage,
                iconSystemName: "doc.zipper",
                iconTint: project.activityStatus == .abandoned ? .red : AppTheme.accent,
                showsCloseButton: true,
                confirm: AppModalActionBar.Action(
                    title: "Hibernate & Compress",
                    systemImage: "doc.zipper",
                    isProminent: true,
                    isDestructive: true,
                    isDefault: true,
                    action: compressProject
                ),
                cancel: AppModalActionBar.CancelAction(title: "Cancel")
            )
        }
        .alert("Couldn't hibernate", isPresented: hibernationErrorBinding) {
            Button("OK", role: .cancel) { hibernationError = nil }
        } message: {
            Text(hibernationError ?? "")
        }
        .alert("Couldn't compress", isPresented: compressionErrorBinding) {
            Button("OK", role: .cancel) { compressionOutcome = nil }
        } message: {
            Text(compressionOutcome?.failureReason ?? "")
        }
        .sheet(isPresented: $showCompressionSuccess) {
            if let outcome = compressionOutcome, outcome.succeeded {
                CompressionSuccessSheet(outcome: outcome)
            }
        }
        .overlay {
            if isCompressing {
                compressingOverlay
            }
        }
    }

    // MARK: - Bindings

    /// The pending action is presented as a sheet via `sheet(item:)` so each
    /// confirmation appears as a full `ConfirmationModal` instead of a
    /// system dialog. Clearing the binding (e.g. via the close X) sets it
    /// back to `nil`.
    private var hibernateConfirmationBinding: Binding<Action?> {
        Binding(
            get: { pendingAction == .hibernate ? .hibernate : nil },
            set: { if $0 == nil { pendingAction = nil } }
        )
    }

    private var compressConfirmationBinding: Binding<Action?> {
        Binding(
            get: { pendingAction == .compress ? .compress : nil },
            set: { if $0 == nil { pendingAction = nil } }
        )
    }

    private var hibernationErrorBinding: Binding<Bool> {
        Binding(
            get: { hibernationError != nil },
            set: { if !$0 { hibernationError = nil } }
        )
    }

    private var compressionErrorBinding: Binding<Bool> {
        Binding(
            get: {
                guard let outcome = compressionOutcome else { return false }
                return !outcome.succeeded
            },
            set: { if !$0 { compressionOutcome = nil } }
        )
    }

    // MARK: - Messages

    private var hibernateMessage: String {
        "This moves \(StorageFormatting.bytes(project.dependencySize)) of regenerable "
            + "dependencies to the Trash and keeps your source. Rebuild them anytime."
    }

    private var compressMessage: String {
        let zipName = ProjectCompressionService.zipURL(for: project).lastPathComponent
        return "This will:\n"
            + "1. Move \(StorageFormatting.bytes(project.dependencySize)) of regenerable "
            + "dependencies to the Trash.\n"
            + "2. Compress the remaining project into \(zipName) in the same folder.\n"
            + "3. Verify the archive is intact, then move the project folder to the Trash.\n\n"
            + "The archive is fully restorable from the same location. Dependencies can be "
            + "rebuilt with a single install command."
    }

    // MARK: - Sections

    private var activityBanner: some View {
        ProjectActivityBanner(project: project)
    }

    private var gitSection: some View {
        Group {
            if project.gitStatus.hasPendingWork {
                GitStatusBanner(gitStatus: project.gitStatus)
            } else if !project.gitStatus.isRepo {
                AppModalSection(
                    title: "Version Control",
                    subtitle: "This project is not tracked by Git",
                    systemImage: "arrow.triangle.branch",
                    tint: .secondary
                ) {
                    AppModalCard {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text("No Git repository found in this project folder.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var sizeBreakdown: some View {
        AppModalSection(
            title: "Size Breakdown",
            subtitle: "How the project's bytes break down",
            systemImage: "chart.pie.fill",
            tint: AppTheme.accent
        ) {
            HStack(spacing: AppTheme.Spacing.mediumLarge) {
                AppModalStat(
                    title: "Total",
                    value: StorageFormatting.bytes(project.totalSize),
                    systemImage: "externaldrive.fill",
                    tint: AppTheme.accent
                )
                AppModalStat(
                    title: "Dependencies",
                    value: StorageFormatting.bytes(project.dependencySize),
                    systemImage: "archivebox.fill",
                    tint: AppTheme.orange
                )
                AppModalStat(
                    title: "Project Data",
                    value: StorageFormatting.bytes(project.projectSize),
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    tint: AppTheme.mint
                )
            }
        }
    }

    private var technologyInfo: some View {
        ProjectTechnologyInfo(project: project, permissionHandler: permissionHandler)
    }

    private var locationInfo: some View {
        ProjectLocationInfo(
            project: project,
            canRevealInFinder: canUseProActions,
            onReveal: revealInFinder
        )
    }

    private var compressingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Compressing project…")
                .font(.headline)
            Text("Verifying the archive before removing the folder.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func revealInFinder() {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
    }

    private func actionHelp(unlocked: String) -> String {
        if project.dependencySize == 0 {
            return "No regenerable dependencies to reclaim."
        }
        if !canUseProActions {
            return "Requires Pro to reclaim project dependencies."
        }
        return unlocked
    }

    private func requestAction(_ action: Action) {
        guard canUseProActions else {
            onRequirePro()
            return
        }
        pendingAction = action
    }

    private func hibernateProject() {
        isHibernating = true
        Task {
            let outcome = await onHibernate(project)
            isHibernating = false
            if outcome.succeeded {
                dismiss()
            } else {
                hibernationError = outcome.failureReason ?? "The project could not be hibernated."
            }
        }
    }

    private func compressProject() {
        isCompressing = true
        Task {
            let outcome = await onCompress(project)
            isCompressing = false
            compressionOutcome = outcome
            if outcome.succeeded {
                // Close the confirmation first so the success sheet can
                // present cleanly; then surface the success sheet.
                pendingAction = nil
                showCompressionSuccess = true
            }
        }
    }

    @Environment(\.dismiss)
    private var dismiss
}

// MARK: - Section subviews

/// Activity banner — the status (active / dormant / inactive / abandoned) plus
/// the last-modified date, designed to read at a glance.
private struct ProjectActivityBanner: View {
    let project: ProjectInfo

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .fill(Color(hex: project.activityStatus.color).opacity(0.14))
                Image(systemName: project.activityStatus.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(hex: project.activityStatus.color))
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(project.activityStatus.label)
                        .font(.headline)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("Modified \(project.lastModifiedRelative)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(project.activityStatus.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .background(
            Color(hex: project.activityStatus.color).opacity(0.06),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(
                    Color(hex: project.activityStatus.color).opacity(0.22),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
    }
}

/// Location card — the project path with a Reveal-in-Finder button.
private struct ProjectLocationInfo: View {
    let project: ProjectInfo
    let canRevealInFinder: Bool
    let onReveal: () -> Void

    var body: some View {
        AppModalSection(
            title: "Location",
            subtitle: "Where the project lives on disk",
            systemImage: "folder.fill",
            tint: AppTheme.cyan
        ) {
            AppModalCard {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.cyan)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.path.lastPathComponent)
                            .font(.subheadline.weight(.medium))
                        Text(project.path.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button(action: onReveal) {
                        Label("Reveal", systemImage: "arrow.up.right.square")
                            .labelStyle(.iconOnly)
                            .font(AppTheme.Typography.rowLabel)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!canRevealInFinder)
                    .accessibilityLabel("Reveal project in Finder")
                }
            }
        }
    }
}

private struct GitStatusBanner: View {
    let gitStatus: GitStatus

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .fill(AppTheme.orange.opacity(0.14))
                Image(systemName: "arrow.triangle.branch")
                    .font(AppTheme.Typography.sectionIcon)
                    .foregroundStyle(AppTheme.orange)
            }
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(gitStatus.hasUncommittedChanges ? "Uncommitted changes" : "Unpushed commits")
                    .font(.headline)
                    .foregroundStyle(AppTheme.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .background(
            AppTheme.orange.opacity(0.06),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(AppTheme.orange.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var message: String {
        var parts: [String] = []
        if gitStatus.hasUncommittedChanges {
            parts.append("Files have been modified but not committed.")
        }
        if gitStatus.hasUnpushedCommits {
            parts.append("Committed changes have not been pushed to the remote.")
        }
        return parts.joined(separator: " ")
    }
}
