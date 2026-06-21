import SwiftUI

/// Post-scan empty result. Used after a scan has completed and there is
/// nothing in the current section to show. Distinct from `InitialStateView`:
/// this is calm, low-motion, and carries a positive "all clean here" tone
/// rather than inviting the user to scan for the first time.
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isBreathing = false

    init(
        title: String,
        message: String,
        systemImage: String = "checkmark.seal.fill",
        tint: Color = AppTheme.mint,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isBreathing ? 0.16 : 0.10))
                    .frame(width: 110, height: 110)
                    .scaleEffect(isBreathing ? 1.04 : 1.0)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 84, height: 84)
                    .overlay {
                        Circle().strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    }

                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.small) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .frame(maxWidth: 420)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("empty-state-action-button")
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }
}
