import SwiftUI

/// The system Preferences window's Settings tab. Mirrors the most
/// impactful preferences from `InAppSettingsView` so the user sees the
/// same controls whether they open the in-app Settings page or the
/// standard `Settings` (⌘,) window.
struct SettingsView: View {
    @AppStorage("includeExternalVolumes")
    private var includeExternalVolumes = false
    @AppStorage("showReviewItems")
    private var showReviewItems = true
    @AppStorage(LargeFileThreshold.storageKey)
    private var largeFileThresholdMB = LargeFileThreshold.defaultMegabytes
    @AppStorage("inactivityThreshold")
    private var inactivityThreshold: InactivityThreshold = .oneMonth

    var body: some View {
        Form {
            Section("Scanning") {
                Toggle("Include connected external volumes", isOn: $includeExternalVolumes)
                Toggle("Show items that require review", isOn: $showReviewItems)
                Picker("Large file threshold", selection: $largeFileThresholdMB) {
                    ForEach(LargeFileThreshold.allCases) { threshold in
                        Text(threshold.label).tag(threshold.megabytes)
                    }
                }
            }

            Section("Project Activity") {
                Picker("Consider inactive after", selection: $inactivityThreshold) {
                    ForEach(InactivityThreshold.allCases) { threshold in
                        Text(threshold.title).tag(threshold)
                    }
                }
            }

            Section("Safety") {
                LabeledContent("Deletion policy", value: "Move to Trash")
                LabeledContent("Confirmation", value: "Always required")
            }

            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Scanner", value: "33 category scanners")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 340)
        .navigationTitle("Settings")
    }
}
