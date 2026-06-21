import SwiftUI

/// The dashboard's per-section scanning view. Thin wrapper around the
/// reusable `ScanningLoaderView` that pulls live state from
/// `DashboardViewModel`. Per-section filtering (e.g. only show the
/// Duplicates page's screenshot/video/document scanners) happens at the
/// call site in `AppShellView`.
struct ScanProgressView: View {
    @Bindable var viewModel: DashboardViewModel
    let title: String
    let subtitle: String
    let visibleScannerKinds: Set<StorageFindingKind>?

    init(
        viewModel: DashboardViewModel,
        title: String = "Scanning storage categories",
        subtitle: String = "This can take a moment on large folders.",
        visibleScannerKinds: Set<StorageFindingKind>? = nil
    ) {
        self.viewModel = viewModel
        self.title = title
        self.subtitle = subtitle
        self.visibleScannerKinds = visibleScannerKinds
    }

    var body: some View {
        ScanningLoaderView(
            title: title,
            subtitle: subtitle,
            progress: viewModel.progress == 0 ? nil : viewModel.progress,
            currentLocation: viewModel.currentLocation,
            scannedItemCount: viewModel.scannedItemCount,
            scanners: filteredScanners,
            cancelAction: viewModel.cancelScan
        )
        .navigationTitle(title)
        .navigationSubtitle("\(StorageFormatting.items(viewModel.scannedItemCount)) inspected")
    }

    private var filteredScanners: [ScannerLoaderItem] {
        let progress = viewModel.scannerProgress.map(ScannerLoaderItem.init(progress:))
        guard let visibleScannerKinds else { return progress }
        return progress.filter { item in
            guard let kind = StorageFindingKind(rawValue: item.id) else { return false }
            return visibleScannerKinds.contains(kind)
        }
    }
}
