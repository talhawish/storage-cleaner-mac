import SwiftUI

struct InAppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("includeExternalVolumes")
    private var includeExternalVolumes = false
    @AppStorage("showReviewItems")
    private var showReviewItems = true
    @AppStorage("largeFileThresholdMB")
    private var largeFileThresholdMB = 100
    @State private var showSafeToDelete = false

    private let thresholdOptions = [10, 50, 100, 500, 1000, 5000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    settingsForm
                }
                .padding(28)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .sheet(isPresented: $showSafeToDelete) {
                SafeToDeleteView()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Settings")
                .font(.largeTitle.bold())
            Text("Configure scanning behavior and app preferences.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsSection(
                title: "Quick Clean",
                icon: "sparkle",
                color: AppTheme.accent
            ) {
                Button {
                    showSafeToDelete = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.mint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Safe to Delete")
                                .font(.subheadline.weight(.medium))
                            Text("Choose which categories are included in Quick Clean")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            settingsSection(
                title: "Scanning",
                icon: "magnifyingglass",
                color: AppTheme.accent
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Include connected external volumes", isOn: $includeExternalVolumes)
                    Toggle("Show items that require review", isOn: $showReviewItems)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Large file threshold")
                            .font(.subheadline.weight(.medium))
                        Picker("", selection: $largeFileThresholdMB) {
                            ForEach(thresholdOptions, id: \.self) { value in
                                Text(StorageFormatting.bytes(Int64(value) * 1_000_000)).tag(value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }

            settingsSection(
                title: "Safety",
                icon: "shield.checkered",
                color: AppTheme.mint
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    safetyRow("Deletion policy", value: "Permanent delete", icon: "trash.fill", color: .red)
                    safetyRow("Confirmation", value: "Always required", icon: "checkmark.shield.fill", color: AppTheme.mint)
                    safetyRow("Scanner mode", value: includeExternalVolumes ? "Full filesystem" : "Home directory only", icon: "externaldrive.fill", color: AppTheme.accent)
                }
            }

            settingsSection(
                title: "About",
                icon: "info.circle.fill",
                color: AppTheme.violet
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    aboutRow("Version", value: "0.1.0")
                    aboutRow("Platform", value: "macOS 14.0+")
                    aboutRow("Scanner", value: "18 category scanners")
                    aboutRow("Architecture", value: "Swift 6, SwiftUI, SwiftData")
                }
            }
        }
    }

    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.headline)
            }

            content()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }
        }
    }

    private func safetyRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func aboutRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}
