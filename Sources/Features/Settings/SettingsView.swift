import SwiftUI

struct SettingsView: View {
    @AppStorage("includeExternalVolumes")
    private var includeExternalVolumes = false
    @AppStorage("showReviewItems")
    private var showReviewItems = true
    @AppStorage("largeFileThresholdMB")
    private var largeFileThresholdMB = 100

    private let thresholdOptions = [10, 50, 100, 500, 1000, 5000]

    var body: some View {
        Form {
            Section("Scanning") {
                Toggle("Include connected external volumes", isOn: $includeExternalVolumes)
                Toggle("Show items that require review", isOn: $showReviewItems)
                Picker("Large file threshold", selection: $largeFileThresholdMB) {
                    ForEach(thresholdOptions, id: \.self) { value in
                        Text(StorageFormatting.bytes(Int64(value) * 1_000_000)).tag(value)
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
