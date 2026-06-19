import SwiftUI

struct ScanSummaryView: View {
    let snapshot: ScanSnapshot
    let startScan: () -> Void

    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.13))
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 76, height: 76)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Potentially reclaimable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(StorageFormatting.bytes(snapshot.reclaimableBytes))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(
                    "\(StorageFormatting.items(snapshot.scannedItemCount)) items inspected in "
                        + StorageFormatting.duration(snapshot.duration)
                )
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Label("Scan complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.mint)
                    .font(.subheadline.weight(.semibold))
                Button("Scan Again", action: startScan)
            }
        }
        .padding(25)
        .cardSurface()
        .accessibilityIdentifier("scan-summary")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(StorageFormatting.bytes(snapshot.reclaimableBytes)) potentially reclaimable, "
                + "\(StorageFormatting.items(snapshot.scannedItemCount)) items inspected"
        )
    }
}
