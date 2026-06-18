import SwiftUI

struct LargeFilesView: View {
    let findings: [StorageFinding]
    let onDelete: ([URL]) -> Void

    @State private var thresholdBytes: Int64 = 100_000_000
    @State private var selectedURLs: Set<URL> = []
    @State private var showDeleteConfirmation = false

    private let thresholdOptions: [(String, Int64)] = [
        ("10 MB", 10_000_000),
        ("50 MB", 50_000_000),
        ("100 MB", 100_000_000),
        ("500 MB", 500_000_000),
        ("1 GB", 1_000_000_000),
        ("5 GB", 5_000_000_000)
    ]

    private var filteredFindings: [StorageFinding] {
        findings.filter { $0.bytes >= thresholdBytes }
    }

    private var allFilePaths: [URL] {
        filteredFindings.flatMap(\.filePaths)
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in
            total + StorageFormatting.fileSize(at: url)
        }
    }

    var body: some View {
        Group {
            if filteredFindings.isEmpty {
                ContentUnavailableView {
                    Label("No Large Files", systemImage: "doc.badge.ellipsis")
                } description: {
                    Text("No storage categories exceed the selected threshold.")
                }
            } else {
                largeFilesList
            }
        }
        .navigationTitle("Large Files")
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
            "Delete \(selectedURLs.count) items?",
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
            Text("This will permanently delete \(selectedURLs.count) items (\(StorageFormatting.bytes(totalSelectedBytes))). This cannot be undone.")
        }
    }

    private var largeFilesList: some View {
        List {
            Section {
                Picker("Minimum size", selection: $thresholdBytes) {
                    ForEach(thresholdOptions, id: \.1) { option in
                        Text(option.0).tag(option.1)
                    }
                }
                .pickerStyle(.segmented)
            }

            ForEach(filteredFindings) { finding in
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
                        Image(systemName: finding.domain.symbolName)
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
