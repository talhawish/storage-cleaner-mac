import SwiftUI

/// SwiftUI previews covering the most common `AppModal` shapes: a detail
/// card, a destructive confirmation, and a preview sheet. These render in
/// Xcode's canvas so designers can iterate without launching the app, and
/// also serve as documentation for the design system.
///
/// Marked `@MainActor` because every `View` initializer it calls is
/// MainActor-isolated under Swift 6's strict concurrency, and `#Preview`
/// doesn't implicitly isolate the helpers below.
@MainActor
enum AppModalPreviews {
    static var detailModal: some View {
        AppModal(idealWidth: 680, minHeight: 460, idealHeight: 540) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: "doc.zipper",
                    iconTint: AppTheme.accent,
                    title: "Project Archived",
                    subtitle: "Reclaimed 412 MB",
                    trailing: .sizeBadge(value: "412 MB", tint: AppTheme.mint),
                    showsCloseButton: true
                )
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        AppModalCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Detail row")
                                Text("Another detail row")
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }
                Divider()
                AppModalActionBar(
                    cancel: AppModalActionBar.CancelAction(title: "Done"),
                    actions: [
                        AppModalActionBar.Action(
                            title: "Show in Finder",
                            systemImage: "folder",
                            tint: AppTheme.accent,
                            isDefault: true
                        )
                    ]
                )
            }
        }
        .padding(40)
        .background(Color.gray.opacity(0.15))
    }

    static var destructiveModal: some View {
        AppModal(idealWidth: 560, minHeight: 420, idealHeight: 460) {
            VStack(spacing: 0) {
                AppModalHeader(
                    iconSystemName: "trash.fill",
                    iconTint: AppTheme.rose,
                    title: "Move 12 items to Trash",
                    subtitle: "Review the selected files before cleanup",
                    trailing: .sizeBadge(value: "1.4 GB", tint: AppTheme.rose),
                    showsCloseButton: false
                )
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                        AppModalBanner(
                            systemImage: "exclamationmark.triangle.fill",
                            tint: AppTheme.orange,
                            text: "These files will be moved to Trash and can be restored until the Trash is emptied."
                        )
                    }
                    .padding(AppTheme.Spacing.extraLarge)
                }
                Divider()
                AppModalActionBar(
                    cancel: AppModalActionBar.CancelAction(title: "Cancel"),
                    actions: [
                        AppModalActionBar.Action(
                            title: "Move to Trash",
                            systemImage: "trash.fill",
                            tint: .red,
                            isProminent: true,
                            isDefault: true
                        )
                    ]
                )
            }
        }
        .padding(40)
        .background(Color.gray.opacity(0.15))
    }
}

#Preview("Detail modal") {
    AppModalPreviews.detailModal
}

#Preview("Destructive modal") {
    AppModalPreviews.destructiveModal
}
