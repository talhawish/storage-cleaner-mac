import SwiftUI

struct DeleteAppConfirmationSheet: View {
    let app: AppItem
    let onDelete: () async -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isPulsing = false
    @State private var isDeleting = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            appDetails
            Divider()
            footer
        }
        .frame(width: 440, height: 340)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
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
                Text("Move to Trash")
                    .font(.title3.weight(.semibold))
                Text("This app will be moved to Trash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
    }

    private var appDetails: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let icon = NSWorkspace.shared.icon(forFile: app.url.path) as NSImage? {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName)
                        .font(.headline)
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(StorageFormatting.bytes(app.sizeBytes))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.rose)
            }
            .padding(16)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            Text("You can reinstall this app from the App Store or its original source at any time.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
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
            .disabled(isDeleting)

            Spacer()

            Button {
                isDeleting = true
                Task { await onDelete() }
            } label: {
                Label("Move to Trash", systemImage: "trash.fill")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(isDeleting)
        }
        .padding(24)
    }
}
