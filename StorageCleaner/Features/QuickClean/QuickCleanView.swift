import SwiftUI

enum QuickCleanPhase {
    case idle
    case scanning
    case review
    case cleaning
    case success
}

private let quickCleanReadyMessage = "Scan and remove safe-to-delete files in one step.\n"
    + "Customize what's included in Settings → Safe to Delete."

private func quickCleanSummary(for result: CleanupResult) -> String {
    "Removed \(result.deletedCount) items, freed \(StorageFormatting.bytes(result.totalBytesReclaimed))"
}

struct QuickCleanView: View {
    let onClean: ([URL]) async -> CleanupResult
    @Environment(\.dismiss)
    private var dismiss

    @State private var phase: QuickCleanPhase = .idle
    @State private var progress = 0.0
    @State private var scannedFindings: [StorageFinding] = []
    @State private var selectedURLs: Set<URL> = []
    @State private var scannedBytesByURL: [URL: Int64] = [:]
    @State private var cleanupResult: CleanupResult?
    @State private var scanStartTime: Date?
    @State private var showCleanConfirmation = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @AppStorage("enabledCleanupOptions")
    private var enabledOptionsData = ""

    private var enabledOptionIDs: Set<String> {
        Set(enabledOptionsData.components(separatedBy: ","))
    }

    private var totalSelectedBytes: Int64 {
        selectedURLs.reduce(Int64(0)) { total, url in
            total + (scannedBytesByURL[url] ?? StorageFormatting.fileSize(at: url))
        }
    }

    private var selectedURLsForCleanup: [URL] {
        selectedURLs.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private var confirmationFinding: StorageFinding {
        StorageFinding(
            kind: .junkFiles,
            domain: .otherCaches,
            bytes: totalSelectedBytes,
            itemCount: selectedURLs.count,
            safety: .safe,
            examples: Array(selectedURLsForCleanup.prefix(3).map(\.lastPathComponent)),
            filePaths: selectedURLsForCleanup
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            switch phase {
            case .idle:
                readyView
            case .scanning:
                scanningView
            case .review:
                reviewView
            case .cleaning:
                cleaningView
            case .success:
                successView
            }
        }
        .frame(width: 640, height: 520)
        .sheet(isPresented: $showCleanConfirmation) {
            DeleteConfirmationSheet(
                finding: confirmationFinding,
                selectedURLs: selectedURLsForCleanup,
                totalBytes: totalSelectedBytes,
                onDelete: {
                    let urls = selectedURLsForCleanup
                    showCleanConfirmation = false
                    performCleanup(urls)
                },
                onCancel: { showCleanConfirmation = false }
            )
        }
    }

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
                Text("Quick Clean")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(20)
    }

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "sparkle")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text("Ready to Quick Clean")
                    .font(.title2.weight(.semibold))
                Text(quickCleanReadyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                startScan()
            } label: {
                Label("Scan & Clean", systemImage: "sparkle.magnifyingglass")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Spacer()
        }
        .padding(28)
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [AppTheme.accent, AppTheme.cyan, AppTheme.accent], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: progress)
                    .frame(width: 100, height: 100)

                Text("\(Int(progress * 100))%")
                    .font(.title2.bold().monospacedDigit())
            }

            VStack(spacing: 6) {
                Text("Scanning safe-to-delete items…")
                    .font(.headline)
                Text("\(scannedFindings.count) categories found so far")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(28)
    }

    private var reviewView: some View {
        VStack(spacing: 0) {
            reviewHeader

            Divider()

            fileList

            Divider()

            reviewFooter
        }
    }

    private var reviewHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.mint.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(AppTheme.mint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Review Quick Clean")
                    .font(.headline)
                Text("\(selectedURLs.count) items, \(StorageFormatting.bytes(totalSelectedBytes)) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Select All") {
                selectedURLs = Set(scannedFindings.flatMap(\.filePaths))
            }
            .font(.subheadline)
        }
        .padding(20)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(scannedFindings) { finding in
                    Section {
                        ForEach(finding.filePaths, id: \.self) { url in
                            fileRow(url, finding: finding)
                        }
                    } header: {
                        HStack {
                            Image(systemName: finding.domain.symbolName)
                                .foregroundStyle(AppTheme.color(for: finding.domain))
                                .accessibilityHidden(true)
                            Text(finding.kind.title)
                            Spacer()
                            Text(StorageFormatting.bytes(finding.bytes))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    private func fileRow(_ url: URL, finding: StorageFinding) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { selectedURLs.contains(url) },
                set: { _ in toggleURL(url) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)

            Image(systemName: url.hasDirectoryPath ? "folder.fill" : "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(url.lastPathComponent)
                .font(.callout.weight(.medium))
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(StorageFormatting.bytes(scannedBytesByURL[url] ?? StorageFormatting.fileSize(at: url)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(url.deletingLastPathComponent().path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 260, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private var reviewFooter: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .buttonStyle(.bordered)
                .controlSize(.large)

            Spacer()

            Button {
                showCleanConfirmation = true
            } label: {
                Label("Review & Confirm", systemImage: "checkmark.shield.fill")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedURLs.isEmpty)
        }
        .padding(20)
    }

    private var cleaningView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Cleaning \(selectedURLs.count) items…")
                .font(.headline)
            Spacer()
        }
    }

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.mint.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .scaleEffect(reduceMotion ? 1 : 1.1)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppTheme.mint)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 6) {
                Text("Clean Complete!")
                    .font(.title2.weight(.semibold))
                if let result = cleanupResult {
                    Text(quickCleanSummary(for: result))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if result.failedCount > 0 {
                        Text("\(result.failedCount) items could not be removed")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)

            Spacer()
        }
        .padding(28)
    }

    private func startScan() {
        phase = .scanning
        progress = 0
        scanStartTime = .now
        scannedFindings = []
        scannedBytesByURL = [:]
        cleanupResult = nil

        Task {
            let scanResult = await performQuickScan()
            guard !Task.isCancelled else { return }

            scannedFindings = scanResult.findings
            scannedBytesByURL = scanResult.bytesByURL
            selectedURLs = Set(scanResult.findings.flatMap(\.filePaths))

            if selectedURLs.isEmpty {
                withAnimation { phase = .success }
                cleanupResult = CleanupResult(deletedURLs: [], deletedItems: [], failedURLs: [], totalBytesReclaimed: 0)
            } else {
                withAnimation { phase = .review }
            }
        }
    }

    private func performQuickScan() async -> QuickCleanScanResult {
        let collector = FileSystemCollector()
        var findings: [StorageFinding] = []
        var bytesByURL: [URL: Int64] = [:]

        let enabledOptions = enabledOptionIDs.isEmpty
            ? CleanupOptionsRegistry.safeByDefaultIDs
            : enabledOptionIDs

        for optionID in enabledOptions {
            guard !Task.isCancelled else { break }
            guard let option = CleanupOptionsRegistry.option(byID: optionID) else { continue }

            let urls = option.paths.map { pathString in
                NSString(string: pathString).expandingTildeInPath
            }.map { URL(fileURLWithPath: $0) }

            let collection = collector.collectExistingItems(at: urls)
            let candidates = collection.candidates
            let totalBytes = candidates.reduce(Int64(0)) { $0 + $1.bytes }

            guard totalBytes > 0 else { continue }

            let finding = StorageFinding(
                kind: .junkFiles,
                domain: option.domain,
                bytes: totalBytes,
                itemCount: candidates.count,
                safety: option.safety,
                examples: [option.name],
                filePaths: candidates.map(\.url)
            )
            findings.append(finding)
            for candidate in candidates {
                bytesByURL[candidate.url] = candidate.bytes
            }

            await MainActor.run {
                progress = Double(findings.count) / Double(max(enabledOptions.count, 1))
            }
        }

        return QuickCleanScanResult(findings: findings, bytesByURL: bytesByURL)
    }

    private func performCleanup(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        phase = .cleaning

        Task {
            let result = await onClean(urls)
            await MainActor.run {
                cleanupResult = result
                withAnimation { phase = .success }
            }
        }
    }

    private func toggleURL(_ url: URL) {
        if selectedURLs.contains(url) {
            selectedURLs.remove(url)
        } else {
            selectedURLs.insert(url)
        }
    }
}

private struct QuickCleanScanResult: Sendable {
    let findings: [StorageFinding]
    let bytesByURL: [URL: Int64]
}
