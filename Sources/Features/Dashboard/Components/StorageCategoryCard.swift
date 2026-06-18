import SwiftUI

struct StorageCategoryCard: View {
    let finding: StorageFinding
    let onNavigate: (StorageFinding) -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        Button(
            action: { onNavigate(finding) },
            label: {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top) {
                    Image(systemName: finding.domain.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppTheme.color(for: finding.domain))
                        .frame(width: 46, height: 46)
                        .background(
                            AppTheme.color(for: finding.domain).opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .accessibilityHidden(true)

                    Spacer()
                    StatusBadge(safety: finding.safety)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(finding.kind.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(finding.kind.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(finding.domain.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.color(for: finding.domain))
                    exampleList
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(StorageFormatting.bytes(finding.bytes))
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(StorageFormatting.items(finding.itemCount)) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
        .cardSurface()
        .scaleEffect(isHovering && !reduceMotion ? 1.015 : 1)
        .shadow(color: .black.opacity(isHovering ? 0.09 : 0.03), radius: isHovering ? 14 : 5, y: 5)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityLabel(
            "\(finding.kind.title), \(finding.domain.title), \(StorageFormatting.bytes(finding.bytes)), "
                + "\(StorageFormatting.items(finding.itemCount)) items, \(finding.safety.title)"
        )
        .accessibilityHint("Opens the category details")
    }

    private var exampleList: some View {
        Text(finding.examples.joined(separator: " • "))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}
