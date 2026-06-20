import SwiftUI

/// The terminal state of Quick Clean: either "Clean Complete!", "Nothing to
/// clean", or "Cleanup failed". Includes an optional per-category breakdown
/// of what was actually removed.
struct QuickCleanSuccessView: View {
    let result: CleanupResult?
    let cleanedCategories: [QuickCleanCategory]
    let onScanAgain: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            HeroBadge(
                systemImage: iconName,
                tint: tint,
                symbolSize: 44
            )
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                if let result {
                    Text(QuickCleanSummaryFormatter.summary(for: result))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let result, result.deletedCount > 0, !cleanedCategories.isEmpty {
                cleanupBreakdown(categories: cleanedCategories)
                    .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button("Close") { onClose() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)

                Button {
                    onScanAgain()
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(28)
    }

    private var iconName: String {
        if let result, result.failedCount > 0, result.deletedCount == 0 {
            return "exclamationmark.triangle.fill"
        }
        return "checkmark.seal.fill"
    }

    private var tint: Color {
        if let result, result.failedCount > 0, result.deletedCount == 0 {
            return AppTheme.orange
        }
        return AppTheme.mint
    }

    private var title: String {
        guard let result else { return "Clean Complete!" }
        if result.deletedCount == 0 && result.failedCount == 0 {
            return "Nothing to clean"
        }
        if result.deletedCount == 0 {
            return "Cleanup failed"
        }
        return "Clean Complete!"
    }

    private func cleanupBreakdown(categories: [QuickCleanCategory]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories cleaned")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                ForEach(categories) { category in
                    HStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .foregroundStyle(QuickCleanPalette.color(for: category))
                            .accessibilityHidden(true)
                        Text(category.name)
                            .font(.subheadline)
                        Spacer()
                        Text(StorageFormatting.bytes(category.bytes))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                AppTheme.subtleSurface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .frame(maxWidth: 420)
    }
}
