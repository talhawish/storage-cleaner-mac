import SwiftUI

/// Confirmation for removing emulator/simulator OS images. Unlike the generic delete sheet, this is
/// explicit about what each removal does: Apple runtimes are *uninstalled* (re-downloadable from
/// Apple), while Android images are *moved to the Trash* (restorable).
struct EmulatorDeleteConfirmationSheet: View {
    let images: [EmulatorImage]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var confirmed = false

    private var totalBytes: Int64 { images.reduce(0) { $0 + $1.bytes } }

    private var hasUninstall: Bool {
        images.contains { if case .simctlRuntime = $0.removal { true } else { false } }
    }

    private var hasTrash: Bool {
        images.contains { $0.removal.isReversible }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            noticeBanner
            imageList
            Divider()
            footer
        }
        .frame(width: 540, height: 480)
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.orange.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "externaldrive.badge.minus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.orange)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Remove \(images.count) OS image\(images.count == 1 ? "" : "s")")
                    .font(.title3.weight(.semibold))
                Text("Reclaims \(StorageFormatting.bytes(totalBytes))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(StorageFormatting.bytes(totalBytes))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.orange)
        }
        .padding(24)
    }

    @ViewBuilder private var noticeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasUninstall {
                noticeRow(
                    systemImage: "arrow.down.circle",
                    tint: AppTheme.accent,
                    text: "Apple simulator runtimes are uninstalled. They can't be recovered from the "
                        + "Trash, but you can re-download them anytime from Xcode."
                )
            }
            if hasTrash {
                noticeRow(
                    systemImage: "trash",
                    tint: AppTheme.mint,
                    text: "Android system images are moved to the Trash, so you can restore them until "
                        + "you empty it."
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func noticeRow(systemImage: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.system(size: 14))
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var imageList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(images) { image in
                    HStack(spacing: 10) {
                        Image(systemName: image.platform.symbolName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.color(for: image.platform.accentColor))
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(image.title)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            Text(image.removal.effectDescription)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(StorageFormatting.bytes(image.bytes))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(.regularMaterial)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel").frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                confirmed = true
                onConfirm()
            } label: {
                Label("Remove \(images.count)", systemImage: "externaldrive.badge.minus")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(confirmed)
        }
        .padding(24)
    }
}
