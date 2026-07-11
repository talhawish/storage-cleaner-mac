import SwiftUI

/// A single stat tile used inside the Cleanup History hero. Composes a tinted icon chip with a
/// big value and a small caption, designed to sit in a flexible `HStack` so a few of them line
/// up at the same baseline.
struct HistoryStatTile: View {
    let title: String
    let value: String
    let caption: String?
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.chip, style: .continuous)
                    .fill(tint.opacity(0.14))
                Image(systemName: systemImage)
                    .font(AppTheme.Typography.bodyIcon)
                    .foregroundStyle(tint)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.mediumLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let caption {
            return "\(title): \(value), \(caption)"
        }
        return "\(title): \(value)"
    }
}
