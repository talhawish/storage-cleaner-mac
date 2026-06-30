import Foundation

/// Discovers per-version iOS / tvOS / watchOS / visionOS Device Support packs under
/// `~/Library/Developer/Xcode/{iOS,tvOS,watchOS,visionOS} DeviceSupport/` and reports each pack as
/// a candidate. The packs contain DWARF debug symbols Xcode downloads when a real device is
/// attached; they are safe to remove and are re-downloaded on demand.
///
/// The Emulators view surfaces the same data with a per-version picker; the dashboard integrates
/// the totals so the Developer Storage screen reflects the full Xcode footprint.
struct IosDeviceSupportScanner: StorageCategoryScanning {
    let kind: StorageFindingKind = .iosDeviceSupport
    let title = StorageFindingKind.iosDeviceSupport.title
    private let roots: [URL]
    private let builder: CandidateFindingBuilder

    init(
        roots: [URL] = DependencyPaths.Apple.deviceSupportRoots,
        builder: CandidateFindingBuilder = CandidateFindingBuilder()
    ) {
        self.roots = roots
        self.builder = builder
    }

    func scan() async -> CategoryScanResult {
        var candidates: [FileCandidate] = []
        var inspectedItemCount = 0

        for root in roots {
            guard !Task.isCancelled else { break }
            let subdirs = EmulatorManagementService.subdirectories(of: root)
            for folder in subdirs {
                guard !Task.isCancelled else { break }
                inspectedItemCount += 1
                let bytes = StorageFormatting.itemSize(at: folder)
                guard bytes > 0 else { continue }
                candidates.append(FileCandidate(url: folder, bytes: bytes))
            }
        }

        let finding = builder.makeFinding(
            kind: kind,
            domain: .appleDevelopment,
            candidates: candidates,
            safety: .safe
        )

        return CategoryScanResult(
            finding: finding,
            inspectedItemCount: inspectedItemCount,
            message: finding == nil
                ? "No Device Support packs found"
                : "Measured \(candidates.count) Device Support pack\(candidates.count == 1 ? "" : "s")"
        )
    }
}
