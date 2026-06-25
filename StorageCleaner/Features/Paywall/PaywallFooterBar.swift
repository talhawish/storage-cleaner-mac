import SwiftUI

/// The bottom strip of the paywall. Two slots:
///
/// - Leading: tiny links to Terms of Service and Privacy Policy
///   (required by App Review guideline 3.1.2).
/// - Trailing: nothing currently.
///
/// Restore Purchases used to live here but was promoted to a
/// dedicated, visible row between the plan cards and the trust
/// strip (`PaywallRestoreLink`) — the footer link was too easy to
/// miss for users who bought on another device and needed to
/// re-claim their entitlement.
///
/// The whole strip stays on one line and the links inherit the
/// app's tint so they read as native controls, not as marketing
/// footer text.
struct PaywallFooterBar: View {
    let onTermsTapped: () -> Void
    let onPrivacyTapped: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            linkGroup
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(AppTheme.appBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppTheme.hairline)
                        .frame(height: 1)
                }
        )
    }

    private var linkGroup: some View {
        HStack(spacing: 14) {
            Button("Terms", action: onTermsTapped)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("paywall-terms")
            Text("·").foregroundStyle(.tertiary)
            Button("Privacy", action: onPrivacyTapped)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("paywall-privacy")
        }
    }
}

/// A dedicated, visible Restore row placed between the plan cards
/// and the trust strip. Required by App Review guideline 3.1.2 for
/// any auto-renewable subscription — and the right UX: a user who
/// bought on another device and is now sitting on the paywall
/// needs Restore to be one tap away, not buried in a footer
/// micro-link.
///
/// Renders as a tappable text button with a small leading
/// "arrow.clockwise" icon, a clear "Already have Pro?" prompt, and
/// an inline spinner while the restore is in flight.
struct PaywallRestoreLink: View {
    let isRestoring: Bool
    let onRestore: () -> Void

    var body: some View {
        Button(action: onRestore) {
            HStack(spacing: 6) {
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(isRestoring ? "Restoring…" : "Already have Pro? Restore Purchases")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(AppTheme.accent.opacity(0.10))
            )
            .overlay {
                Capsule().stroke(AppTheme.accent.opacity(0.25), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .help("Restore a purchase made on another device with this Apple ID.")
        .accessibilityIdentifier("paywall-restore-purchases")
    }
}
