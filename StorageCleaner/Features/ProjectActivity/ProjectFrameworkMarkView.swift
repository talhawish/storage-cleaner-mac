import SwiftUI

struct ProjectFrameworkMarkView: View {
    let framework: ProjectFramework
    var size: CGFloat = 38

    private var identity: ProjectFrameworkVisualIdentity {
        framework.visualIdentity
    }

    private var tint: Color {
        identity.tintHex.map(Color.init(hex:)) ?? .primary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .fill(tint.opacity(0.13))

            if let systemImage = identity.systemImage {
                Image(systemName: systemImage)
                    .font(.headline)
            } else {
                Text(identity.mark)
                    .font(.caption.bold())
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(AppTheme.Spacing.extraSmall)
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.small)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
