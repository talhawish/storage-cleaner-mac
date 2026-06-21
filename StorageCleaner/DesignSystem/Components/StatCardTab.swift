import SwiftUI

/// Pill-shaped stat card with a SF Symbol, title, byte total, and "X categories" subtitle. Used as
/// a tappable filter chip on overview screens (e.g. Developer Storage, System Junk). The
/// `DeveloperDomainTab` and any future "selectable stat card" should use this component so the
/// visual rhythm stays consistent across surfaces.
struct StatCardTab: View {
    let title: String
    let count: Int
    let bytes: Int64
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void
    let countLabel: String

    init(
        title: String,
        count: Int,
        bytes: Int64,
        systemImage: String,
        tint: Color,
        isSelected: Bool,
        countLabel: String = "categories",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.bytes = bytes
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
        self.countLabel = countLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)

                    Spacer(minLength: 6)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(StorageFormatting.bytes(bytes))
                        .font(.headline.monospacedDigit())

                    Text("\(count) \(countLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: 178, height: 116, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? tint.opacity(0.16) : Color.secondary.opacity(0.08))
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isSelected ? tint : Color.clear)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.55) : Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityLabel("\(title), \(count) \(countLabel), \(StorageFormatting.bytes(bytes))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
