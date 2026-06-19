import SwiftUI

struct DeleteConfirmationSheet: View {
    let finding: StorageFinding
    let selectedURLs: [URL]
    let totalBytes: Int64
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isPulsing = false
    @State private var confirmed = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            warningBanner

            fileList

            Divider()

            footer
        }
        .frame(width: 520, height: 480)
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.rose.opacity(0.12))
                    .frame(width: 52, height: 52)
                    .scaleEffect(isPulsing ? 1.08 : 1.0)

                Image(systemName: "trash.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppTheme.rose)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Move \(selectedURLs.count) items to Trash")
                    .font(.title3.weight(.semibold))
                Text("Review the selected files before cleanup")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(StorageFormatting.bytes(totalBytes))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.rose)
        }
        .padding(24)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.orange)
                .font(.system(size: 14))
                .accessibilityHidden(true)

            Text("These files will be moved to Trash and can be restored until the Trash is emptied.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(14)
        .background(AppTheme.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(selectedURLs.prefix(50), id: \.self) { url in
                    fileRow(url)
                    if url != selectedURLs.prefix(50).last {
                        Divider().padding(.leading, 52)
                    }
                }

                if selectedURLs.count > 50 {
                    Text("… and \(selectedURLs.count - 50) more items")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                }
            }
        }
        .background(.regularMaterial)
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconForURL(url))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor(url))
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(url.deletingLastPathComponent().lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .frame(minWidth: 80)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                confirmed = true
                onDelete()
            } label: {
                Label("Move to Trash", systemImage: "trash.fill")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(confirmed)
        }
        .padding(24)
    }

    private func iconForURL(_ url: URL) -> String {
        if url.hasDirectoryPath { return "folder.fill" }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm": return "film.fill"
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng": return "photo.fill"
        case "apk", "aab": return "app.badge.fill"
        case "dmg": return "opticaldisc.fill"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "log", "crash": return "doc.text.fill"
        case "tmp", "temp": return "doc.badge.clock.fill"
        default: return "doc.fill"
        }
    }

    private func iconColor(_ url: URL) -> Color {
        if url.hasDirectoryPath { return AppTheme.accent }
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm": return AppTheme.pink
        case "jpg", "jpeg", "png", "heic", "tiff", "raw", "dng": return AppTheme.rose
        case "apk", "aab": return AppTheme.orange
        case "dmg": return AppTheme.violet
        case "zip", "tar", "gz": return AppTheme.indigo
        default: return .secondary
        }
    }
}

struct CategoryInfoSheet: View {
    let finding: StorageFinding
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.color(for: finding.domain).opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: finding.domain.symbolName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(AppTheme.color(for: finding.domain))
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(finding.kind.title)
                    .font(.title2.weight(.semibold))
                Text(finding.kind.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            VStack(spacing: 16) {
                infoRow("Domain", finding.domain.title)
                infoRow("Total Size", StorageFormatting.bytes(finding.bytes))
                infoRow("Items", "\(finding.itemCount)")
                infoRow("Safety", finding.safety.title)
                if !finding.examples.isEmpty {
                    infoRow("Includes", finding.examples.joined(separator: ", "))
                }
            }

            Spacer()
        }
        .padding(28)
        .frame(width: 440, height: 460)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }
}
