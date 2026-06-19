import SwiftUI

/// One card per platform (Apple Simulators / Android System Images) listing its installed OS images.
struct EmulatorSectionCard: View {
    let platform: EmulatorPlatform
    let images: [EmulatorImage]
    let selectedIDs: Set<String>
    let onToggle: (EmulatorImage) -> Void
    let onToggleAll: () -> Void

    private var accent: Color { AppTheme.color(for: platform.accentColor) }

    private var removableImages: [EmulatorImage] { images.filter(\.isRemovable) }

    private var allRemovableSelected: Bool {
        !removableImages.isEmpty && removableImages.allSatisfy { selectedIDs.contains($0.id) }
    }

    private var totalBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 2) {
                ForEach(images) { image in
                    EmulatorRow(
                        image: image,
                        isSelected: selectedIDs.contains(image.id),
                        onToggle: { onToggle(image) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
        .cardSurface()
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: platform.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(platform.title)
                    .font(.headline)
                Text("\(images.count) installed · \(StorageFormatting.bytes(totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !removableImages.isEmpty {
                Button(action: onToggleAll) {
                    Text(allRemovableSelected ? "Deselect all" : "Select all")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
    }
}
