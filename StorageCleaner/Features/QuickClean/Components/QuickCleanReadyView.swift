import SwiftUI

/// The idle / "ready to scan" state of Quick Clean. Centers a hero badge,
/// a short explainer, and the primary action so the user always knows what
/// tapping the button will do.
struct QuickCleanReadyView: View {
    let onStartScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            HeroBadge(
                systemImage: "sparkles",
                tint: AppTheme.accent,
                symbolSize: 44
            )
            VStack(spacing: 10) {
                Text("Ready to Quick Clean")
                    .font(.title2.weight(.semibold))
                Text(
                    "We'll scan the categories you've enabled in Settings and group every"
                        + " recoverable file so you can pick what to remove."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
            }
            Button {
                onStartScan()
            } label: {
                Label("Scan & Clean", systemImage: "arrow.clockwise")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Starts the Quick Clean scan")
            Spacer()
        }
        .padding(28)
    }
}
