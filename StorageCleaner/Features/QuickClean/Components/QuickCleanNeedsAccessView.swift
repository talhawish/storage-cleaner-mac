import SwiftUI

/// The "Home Folder access is required" state of Quick Clean. Reached only
/// on sandboxed builds when the user opens the modal without first granting
/// home folder access through the dashboard. Dismisses the modal so the
/// user can run the dashboard's existing permission flow — re-opening
/// Quick Clean afterwards picks up the new grant and proceeds normally.
struct QuickCleanNeedsAccessView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            HeroBadge(
                systemImage: "lock.shield.fill",
                tint: AppTheme.orange,
                symbolSize: 44
            )
            VStack(spacing: 10) {
                Text("Home Folder access is required")
                    .font(.title2.weight(.semibold))
                Text(
                    "Quick Clean needs Home Folder access to measure the developer caches and"
                        + " app data it cleans. Close this and grant access from the dashboard,"
                        + " then reopen Quick Clean to scan."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
            }
            Button {
                onClose()
            } label: {
                Label("Close", systemImage: "xmark")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            Spacer()
        }
        .padding(28)
    }
}
