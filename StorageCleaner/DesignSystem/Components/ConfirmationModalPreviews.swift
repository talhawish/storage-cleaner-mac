import SwiftUI

/// SwiftUI previews for `ConfirmationModal` covering every variant. These
/// render in Xcode's canvas so designers can iterate without launching the
/// app, and also serve as living documentation of the design system.
///
/// Marked `@MainActor` because every `View` initializer it calls is
/// MainActor-isolated under Swift 6's strict concurrency, and `#Preview`
/// doesn't implicitly isolate the helpers below.
@MainActor
enum ConfirmationModalPreviews {
    static var info: some View {
        ConfirmationModal(
            variant: .info,
            title: "Scan complete",
            subtitle: "Storage Cleaner finished in 4 seconds",
            message: "12.4 GB of reclaimable space across 6 categories.",
            confirm: AppModalActionBar.Action(
                title: "Review findings",
                systemImage: "arrow.right.circle.fill",
                isProminent: true,
                isDefault: true
            ),
            cancel: AppModalActionBar.CancelAction(title: "Not now")
        )
    }

    static var warning: some View {
        ConfirmationModal(
            variant: .warning,
            title: "Hibernate this project?",
            message: "This moves 412 MB of regenerable dependencies to the Trash "
                + "and keeps your source. Rebuild them anytime.",
            confirm: AppModalActionBar.Action(
                title: "Move Dependencies to Trash",
                systemImage: "archivebox.fill",
                isProminent: true,
                isDefault: true
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel")
        )
    }

    static var destructiveSimple: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Move to Trash",
            subtitle: "This app will be moved to Trash",
            trailing: .sizeBadge(value: "412 MB", tint: AppTheme.rose),
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: "Move to Trash",
                systemImage: "trash.fill",
                isProminent: true,
                isDestructive: true,
                isDefault: true
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel")
        )
    }

    static var destructiveRich: some View {
        ConfirmationModal(
            variant: .destructive,
            title: "Move 12 items to Trash?",
            subtitle: "Review the selected files before cleanup",
            trailing: .sizeBadge(value: "1.4 GB", tint: AppTheme.rose),
            showsCloseButton: false,
            confirm: AppModalActionBar.Action(
                title: "Move to Trash",
                systemImage: "trash.fill",
                isProminent: true,
                isDestructive: true,
                isDefault: true
            ),
            cancel: AppModalActionBar.CancelAction(title: "Cancel")
        ) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("file-\(index + 1).pdf")
                                .font(.callout.weight(.medium))
                            Text("/Users/me/Documents/file-\(index + 1).pdf")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    if index < 4 { Divider().padding(.leading, 44) }
                }
            }
            .cardSurface()
        }
    }

    static var success: some View {
        ConfirmationModal(
            variant: .success,
            title: "Cleanup complete",
            subtitle: "Reclaimed 8.2 GB across 312 items",
            message: "Removed items are in the Trash until you empty it. "
                + "Most caches will rebuild automatically on next use.",
            confirm: AppModalActionBar.Action(
                title: "Done",
                systemImage: "checkmark",
                tint: AppTheme.mint,
                isProminent: true,
                isDefault: true
            )
        )
    }
}

#Preview("Info") { ConfirmationModalPreviews.info }
#Preview("Warning") { ConfirmationModalPreviews.warning }
#Preview("Destructive — simple") { ConfirmationModalPreviews.destructiveSimple }
#Preview("Destructive — rich") { ConfirmationModalPreviews.destructiveRich }
#Preview("Success") { ConfirmationModalPreviews.success }
