import SwiftUI

/// "Allow Home Folder Access" hero shown on the Overview and every section
/// that needs Home access to start a scan.
///
/// Replaces the old text-heavy modal-style card with an inviting
/// graphic-first composition: an animated folder orb with six
/// developer-domain chips orbiting around it, a single primary CTA, and a
/// tiny security pill. Copy is reduced to one headline + one sentence + one
/// trust line, so the user can grasp the ask in a glance.
struct PermissionRequiredView: View {
    let blockedPermissions: [StoragePermissionStatus]
    let onOpenSettings: () -> Void
    let onGrantAccess: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(spacing: AppTheme.Spacing.extraLarge) {
            PermissionRequiredHero(reduceMotion: reduceMotion)
                .padding(.top, AppTheme.Spacing.medium)
                .accessibilityHidden(true)

            headline

            CoveredScopeRow()
                .padding(.horizontal, AppTheme.Spacing.small)

            actions

            TrustPill()
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 56)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("permission-guide-card")
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Text("Grant Home access")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("One permission lets Storage Cleaner see your Mac — and find what to clean.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 480)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Button(action: onGrantAccess) {
                Label("Choose Home Folder", systemImage: "folder.badge.plus")
                    .font(.headline)
                    .frame(minWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("permission-choose-home")
            .accessibilityHint("Opens Finder so you can select your Home folder")

            Button("Open System Settings", systemImage: "gearshape", action: onOpenSettings)
                .buttonStyle(.link)
                .controlSize(.small)
                .accessibilityIdentifier("permission-open-system-settings")
        }
    }
}

// MARK: - Covered scope row

/// One row of small, breathing icon chips that names the locations the Home
/// permission covers. Each chip pairs an SF Symbol with a short label
/// (Desktop, Documents, …), so the visual inventory reads as a glance-able
/// promise rather than a paragraph of explanation.
private struct CoveredScopeRow: View {
    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let color: Color
    }

    private let items: [Item] = [
        Item(id: "Desktop", symbol: "desktopcomputer", color: AppTheme.accent),
        Item(id: "Documents", symbol: "doc.fill", color: AppTheme.cyan),
        Item(id: "Downloads", symbol: "arrow.down.circle.fill", color: AppTheme.violet),
        Item(id: "Movies", symbol: "film.fill", color: AppTheme.pink),
        Item(id: "Pictures", symbol: "photo.fill", color: AppTheme.orange),
        Item(id: "Library", symbol: "books.vertical.fill", color: AppTheme.indigo)
    ]

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(items) { item in
                CoveredScopeChip(symbol: item.symbol, color: item.color, title: item.id)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Home access covers Desktop, Documents, Downloads, Movies, Pictures, and Library.")
    }
}

/// A small icon + label pill used in the `CoveredScopeRow`. Each chip
/// breathes gently to keep the row feeling alive.
private struct CoveredScopeChip: View {
    let symbol: String
    let color: Color
    let title: String

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(isBreathing ? 0.20 : 0.12))
                    .frame(width: 42, height: 42)
                    .scaleEffect(isBreathing ? 1.04 : 1.0)

                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle().strokeBorder(color.opacity(0.25), lineWidth: 0.5)
                    }

                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}

// MARK: - Trust pill

/// A small mint-tinted pill that reassures the user the Home bookmark is
/// stored by macOS — never uploaded, never persisted outside the app's
/// security scope.
/// A small mint-tinted pill that reassures the user — Apple style — that
/// the grant stays on their Mac and they can revoke it whenever. Wording
/// is deliberately non-technical: the user doesn't need to know what a
/// security-scoped bookmark is, only that nothing leaves their machine and
/// they stay in control.
private struct TrustPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mint)
                .accessibilityHidden(true)
            Text("Your files stay on your Mac. You can revoke this any time.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.mint.opacity(0.10), in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.mint.opacity(0.22), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your files stay on your Mac. You can revoke this any time.")
    }
}
