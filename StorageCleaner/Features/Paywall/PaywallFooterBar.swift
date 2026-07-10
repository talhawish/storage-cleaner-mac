import SwiftUI

/// The bottom strip of the paywall. Shows the mandatory auto-renewal
/// disclosure followed by links to the Terms of Use and Privacy Policy.
///
/// Restore Purchases used to live here but was promoted to a
/// dedicated, visible row between the plan cards and the trust
/// strip (`PaywallRestoreLink`) — the footer link was too easy to
/// miss for users who bought on another device and needed to
/// re-claim their entitlement.
///
struct PaywallFooterBar: View {
    let onTermsTapped: () -> Void
    let onPrivacyTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(SubscriptionDisclosure.autoRenewal)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall-auto-renewal-disclosure")
            linkGroup
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
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
            Button("Terms of Use", action: onTermsTapped)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("paywall-terms")
            Text("·").foregroundStyle(.tertiary)
            Button("Privacy Policy", action: onPrivacyTapped)
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
