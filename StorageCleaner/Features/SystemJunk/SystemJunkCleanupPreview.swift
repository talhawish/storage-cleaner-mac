import SwiftUI

struct SystemJunkCleanupPreview: View {
    let urls: [URL]

    var body: some View {
        AppModalSection(
            title: "Items to delete",
            subtitle: "Up to 50 are shown",
            systemImage: "doc.on.doc.fill",
            tint: AppTheme.rose
        ) {
            VStack(spacing: 0) {
                ForEach(Array(urls.prefix(50).enumerated()), id: \.element) { index, url in
                    fileRow(url)
                    if index < min(urls.count, 50) - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(.vertical, 4)
            .cardSurface()

            if urls.count > 50 {
                Text("... and \(urls.count - 50) more items")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    private func fileRow(_ url: URL) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconForURL(url))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(url.hasDirectoryPath ? AppTheme.accent : .secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(url.standardizedFileURL.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(url.standardizedFileURL.path)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func iconForURL(_ url: URL) -> String {
        if url.hasDirectoryPath {
            return "folder.fill"
        }
        switch url.pathExtension.lowercased() {
        case "crash", "diag", "hang", "ips", "memory", "panic", "spin", "synced":
            return "doc.text.fill"
        case "plist":
            return "slider.horizontal.3"
        default:
            return "doc.fill"
        }
    }
}
