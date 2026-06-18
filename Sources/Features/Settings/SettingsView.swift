import SwiftUI

struct SettingsView: View {
    @AppStorage("includeExternalVolumes")
    private var includeExternalVolumes = false
    @AppStorage("showReviewItems")
    private var showReviewItems = true

    var body: some View {
        Form {
            Section("Scanning") {
                Toggle("Include connected external volumes", isOn: $includeExternalVolumes)
                Toggle("Show items that require review", isOn: $showReviewItems)
            }

            Section("Safety") {
                LabeledContent("Deletion policy", value: "Always ask first")
                LabeledContent("Current scanner", value: "Demonstration data")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 280)
        .navigationTitle("Settings")
    }
}
