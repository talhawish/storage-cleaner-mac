import SwiftUI

struct MediaPreviewSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            if let image {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack(spacing: 16) {
                Label(StorageFormatting.bytes(StorageFormatting.fileSize(at: url)), systemImage: "doc")
                Label(dateString, systemImage: "clock")
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear { loadImage() }
    }

    private var dateString: String {
        let date = StorageFormatting.modificationDate(at: url)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadImage() {
        Task.detached(priority: .utility) {
            let img = NSImage(contentsOf: url)
            await MainActor.run { self.image = img }
        }
    }
}
