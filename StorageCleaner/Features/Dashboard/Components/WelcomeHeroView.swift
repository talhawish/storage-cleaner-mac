import SwiftUI

struct WelcomeHeroView: View {
    let startScan: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 18) {
                Label("Developer-aware analysis", systemImage: "wand.and.stars")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Text("Find the space your tools leave behind.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Scan build artifacts, simulators, package caches, browser caches, large videos, "
                        + "photos, screenshots, Trash, leftover APKs, containers, and local AI models. "
                        + "You stay in control of every cleanup."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

                Button(action: startScan) {
                    Label("Start Smart Scan", systemImage: "sparkle.magnifyingglass")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("primary-scan-button")
                .accessibilityHint("Scans developer storage locations without deleting files")
            }

            Spacer(minLength: 10)

            StorageOrbView()
                .frame(width: 230, height: 230)
                .accessibilityHidden(true)
        }
        .padding(30)
        .cardSurface()
    }
}
