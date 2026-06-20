import SwiftUI

/// The "moving files to Trash" state. Centered spinner + copy.
struct QuickCleanCleaningView: View {
    let itemCount: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            VStack(spacing: 6) {
                Text("Cleaning \(StorageFormatting.items(itemCount))…")
                    .font(.headline)
                Text("Moving the selected items to Trash.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(28)
    }
}
