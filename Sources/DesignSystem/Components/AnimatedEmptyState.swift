import SwiftUI

struct AnimatedEmptyState: View {
    let title: String
    let message: String
    let actionTitle: String?
    let systemImage: String
    let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isFloating = false

    init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        systemImage: String = "checkmark.seal.fill",
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.mint.opacity(0.12))
                    .frame(width: 104, height: 104)

                Image(systemName: systemImage)
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(AppTheme.mint)
                    .offset(y: isFloating ? -3 : 3)
            }
            .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(title)
                    .font(.title2.weight(.semibold))

                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}
