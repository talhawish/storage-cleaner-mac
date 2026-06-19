import SwiftUI

/// Consistent section header: icon + title + optional subtitle and trailing accessory.
struct SectionHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = AppTheme.accent
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: AppTheme.IconSize.body, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            accessory()
        }
    }
}

extension SectionHeader where Accessory == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = AppTheme.accent
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            accessory: { EmptyView() }
        )
    }
}
