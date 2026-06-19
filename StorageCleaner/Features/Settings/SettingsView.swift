import SwiftUI

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
                LabeledContent("Deletion policy", value: "Permanent delete")
                LabeledContent("Confirmation", value: "Always required")
            }

            Section("About") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Scanner", value: includeExternalVolumes ? "Full filesystem" : "Home directory only")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 340)
        .navigationTitle("Settings")
    }
}
