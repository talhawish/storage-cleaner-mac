import SwiftUI

/// The terminal state of Quick Clean: either "Clean Complete!", "Nothing to
/// clean", or "Cleanup failed". Includes an optional per-category breakdown
/// of what was actually removed, and an optional "free before / after" pill
/// when the caller captured disk-space snapshots.
struct QuickCleanSuccessView: View {
    let result: CleanupResult?
    let cleanedCategories: [QuickCleanCategory]
    let freeBytesBefore: Int64?
    let freeBytesAfter: Int64?
    let onScanAgain: () -> Void
    let onClose: () -> Void

    init(
        result: CleanupResult?,
        cleanedCategories: [QuickCleanCategory],
        freeBytesBefore: Int64? = nil,
        freeBytesAfter: Int64? = nil,
        onScanAgain: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.result = result
        self.cleanedCategories = cleanedCategories
        self.freeBytesBefore = freeBytesBefore
        self.freeBytesAfter = freeBytesAfter
        self.onScanAgain = onScanAgain
        self.onClose = onClose
    }

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

            if showsDiskImpact {
                FreeSpaceImpactPill(
                    freeBytesBefore: freeBytesBefore ?? 0,
                    freeBytesAfter: freeBytesAfter ?? 0
                )
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

    private var showsDiskImpact: Bool {
        guard let before = freeBytesBefore, let after = freeBytesAfter else { return false }
        return before > 0 && after > 0
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

/// Pill rendered inside the Quick Clean success view when the caller passed
/// free-bytes snapshots. Shows the volume's free space before the cleanup
/// and the freshly-captured free space after, plus a green "grew by X" call-out.
private struct FreeSpaceImpactPill: View {
    let freeBytesBefore: Int64
    let freeBytesAfter: Int64

    private var delta: Int64 {
        freeBytesAfter - freeBytesBefore
    }

    private var tint: Color { delta > 0 ? AppTheme.mint : .secondary }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text("Free before")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(StorageFormatting.bytes(freeBytesBefore))
                .font(.caption.weight(.semibold).monospacedDigit())
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Free after")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(StorageFormatting.bytes(freeBytesAfter))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            if delta > 0 {
                Text("+\(StorageFormatting.bytes(delta))")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(tint.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .frame(maxWidth: 420)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Free space \(StorageFormatting.bytes(freeBytesBefore)) before, "
                + "\(StorageFormatting.bytes(freeBytesAfter)) after"
                + (delta > 0 ? ", grew by \(StorageFormatting.bytes(delta))" : "")
        )
    }
}
