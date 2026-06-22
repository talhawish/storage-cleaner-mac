import SwiftUI

struct AppRowView: View {
    let app: AppItem
    let onReveal: () -> Void
    let onUninstall: () -> Void

    @State private var appIcon: NSImage?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            appIconView

            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(app.url.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(StorageFormatting.bytes(app.sizeBytes))
                    .font(.callout.monospacedDigit().weight(.medium))

                if app.isSystemApp {
                    Text("System")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if isHovering {
                actionButtons
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovering ? Color.accentColor.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovering = $0 }
        .contextMenu {
            contextMenuContent
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.displayName), \(StorageFormatting.bytes(app.sizeBytes))")
    }

    private var appIconView: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task {
            appIcon = NSWorkspace.shared.icon(forFile: app.url.path)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 4) {
            Button {
                onReveal()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal in Finder")

            if !app.isSystemApp {
                Button {
                    onUninstall()
                } label: {
                    Image(systemName: "xmark.bin")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .help("Uninstall")
                .accessibilityLabel("Uninstall")
            }
        }
    }

    @ViewBuilder private var contextMenuContent: some View {
        Button("Reveal in Finder") { onReveal() }
        Button("Copy Name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(app.displayName, forType: .string)
        }
        Button("Copy Bundle ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(app.bundleIdentifier, forType: .string)
        }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(app.url.path, forType: .string)
        }
        if !app.isSystemApp {
            Divider()
            Button("Uninstall", role: .destructive) { onUninstall() }
        }
    }
}
