import SwiftUI

struct ScanProgressView: View {
    @Bindable var viewModel: DashboardViewModel
    let title: String
    let subtitle: String
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init(
        viewModel: DashboardViewModel,
        title: String = "Scanning storage categories",
        subtitle: String = "This can take a moment on large folders."
    ) {
        self.viewModel = viewModel
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent, AppTheme.cyan, AppTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: viewModel.progress)

                VStack(spacing: 3) {
                    if isPreparing {
                        ProgressView()
                            .controlSize(.large)
                            .accessibilityLabel("Preparing scan")
                    } else {
                        Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("complete")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 170, height: 170)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scan progress")
            .accessibilityValue(viewModel.progress.formatted(.percent.precision(.fractionLength(0))))

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .accessibilityIdentifier("scan-progress-title")
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(viewModel.currentLocation)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(StorageFormatting.items(viewModel.scannedItemCount)) items inspected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)

            scannerProgressList

            Button("Cancel Scan", role: .cancel, action: viewModel.cancelScan)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("cancel-scan-button")
        }
        .padding(44)
        .frame(maxWidth: .infinity, minHeight: 440)
        .cardSurface()
        .navigationTitle(title)
        .navigationSubtitle("\(StorageFormatting.items(viewModel.scannedItemCount)) inspected")
    }

    private var isPreparing: Bool {
        viewModel.isScanning && viewModel.progress == 0
    }

    @ViewBuilder private var scannerProgressList: some View {
        if !viewModel.scannerProgress.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 230), spacing: 12)],
                spacing: 12
            ) {
                ForEach(viewModel.scannerProgress) { progress in
                    ScannerProgressRow(progress: progress)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: viewModel.scannerProgress)
        }
    }
}

private struct ScannerProgressRow: View {
    let progress: ScannerProgress

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.title), \(statusText)")
    }

    private var statusText: String {
        if progress.inspectedItemCount > 0 {
            return "\(StorageFormatting.items(progress.inspectedItemCount)) items, \(progress.message)"
        }

        return progress.message
    }

    private var symbolName: String {
        switch progress.state {
        case .pending: "clock"
        case .scanning: "arrow.triangle.2.circlepath"
        case .completed: "checkmark"
        case .skipped: "minus"
        }
    }

    private var tint: Color {
        switch progress.state {
        case .pending: .secondary
        case .scanning: AppTheme.accent
        case .completed: AppTheme.mint
        case .skipped: .secondary
        }
    }
}
