import SwiftUI

struct DockerMetricTile: View {
    let title: String
    let value: String
    let usedBytes: Int64
    let reclaimableBytes: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            Text(StorageFormatting.bytes(usedBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if let reclaimableBytes, reclaimableBytes > 0 {
                Label(
                    "\(StorageFormatting.bytes(reclaimableBytes)) reclaimable",
                    systemImage: "arrow.down.circle"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.mint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.subtleSurface)
        .clipShape(.rect(cornerRadius: AppTheme.Radius.small))
        .accessibilityElement(children: .combine)
    }
}
