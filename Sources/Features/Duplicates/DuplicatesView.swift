import SwiftUI

struct DuplicatesView: View {
    let findings: [StorageFinding]
    let onDelete: ([URL]) -> Void

    private let duplicateKinds: [StorageFindingKind] = [
        .duplicatePhotos,
        .duplicateVideos
    ]

    private var duplicateFindings: [StorageFinding] {
        findings.filter { duplicateKinds.contains($0.kind) }
    }

    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in
            total + StorageFormatting.fileSize(at: url)
        }
    }

    var body: some View {
        Group {
            if duplicateFindings.isEmpty {
                AnimatedEmptyState(
                    title: "No Duplicates Found",
                    message: "Run a scan to detect duplicate photos and videos.",
                    systemImage: "square.on.square"
                )
            } else {
                duplicatesList
            }
        }
        .navigationTitle("Duplicates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !selectedURLs.isEmpty {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Delete \(selectedURLs.count) duplicate items?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                let urls = Array(selectedURLs)
                selectedURLs.removeAll()
                onDelete(urls)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(selectedURLs.count) duplicates (\(StorageFormatting.bytes(totalSelectedBytes))). This cannot be undone.")
        }
    }

    private var duplicatesList: some View {
        List {
            ForEach(duplicateFindings) { finding in
                Section {
                    ForEach(finding.filePaths, id: \.self) { url in
                        FileRowView(
                            url: url,
                            isSelected: selectedURLs.contains(url),
                            onToggle: { toggle(url) }
                        )
                    }
                } header: {
                    HStack {
                        Image(systemName: finding.kind == .duplicatePhotos ? "photo.stack.fill" : "film.stack.fill")
                            .foregroundStyle(AppTheme.color(for: finding.domain))
                        Text(finding.kind.title)
                        Spacer()
                        Text(StorageFormatting.bytes(finding.bytes))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func toggle(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }
}
