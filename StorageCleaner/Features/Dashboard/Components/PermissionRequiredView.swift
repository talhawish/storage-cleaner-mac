import SwiftUI

struct PermissionRequiredView: View {
    let blockedPermissions: [StoragePermissionStatus]
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var isPulsing = false
    @State private var retryAttempt = 0

    var body: some View {
        VStack(spacing: 26) {
            animatedIcon

            VStack(spacing: 8) {
                Text("Storage Cleaner needs access")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text("Some storage locations couldn't be read. Grant Full Disk Access "
                    + "so the scanner can inspect developer folders, caches, and media.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            blockedLocationsList

            guidanceSteps

            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("permission-retry-button")

                Button(action: onOpenSettings) {
                    Label("Open System Settings", systemImage: "gearshape.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("permission-open-settings-button")
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, minHeight: 440)
        .cardSurface()
        .id(retryAttempt)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var animatedIcon: some View {
        ZStack {
            Circle()
                .fill(AppTheme.orange.opacity(0.06))
                .frame(width: 132, height: 132)
                .scaleEffect(isPulsing ? 1.12 : 1.0)

            Circle()
                .fill(AppTheme.orange.opacity(0.12))
                .frame(width: 104, height: 104)
                .scaleEffect(isPulsing ? 1.06 : 1.0)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46, weight: .medium))
                .foregroundStyle(AppTheme.orange)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var blockedLocationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blockedPermissions) { permission in
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.orange)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(permission.scope.title)
                            .font(.subheadline.weight(.medium))
                        Text(permission.state.guidance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(permission.scope.title), \(permission.state.guidance)")
            }
        }
        .frame(maxWidth: 480)
    }

    private var guidanceSteps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Open System Settings → Privacy & Security", systemImage: "1.circle.fill")
            Label("Enable Full Disk Access for Storage Cleaner", systemImage: "2.circle.fill")
            Label("Click Retry to scan again", systemImage: "3.circle.fill")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: 480, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}
