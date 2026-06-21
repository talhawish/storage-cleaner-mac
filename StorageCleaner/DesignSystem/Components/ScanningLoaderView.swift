import SwiftUI

/// Reusable scanning loader. Used by both the dashboard's per-section
/// scanners (which report progress through `DashboardViewModel`) and the
/// self-discovering views (Project Activity, Emulators, Runtime Versions,
/// CLI Programs, Apps) which report their own progress.
///
/// Renders a flat, centered hero: an animated progress ring with a percentage,
/// the current activity, the items inspected so far, a list of named "scanners"
/// (each with its own icon, tint, and state), and a prominent cancel button.
/// When `progress` is `nil` the ring renders as an indeterminate spinner. The
/// content is capped at a comfortable reading width and centered in the
/// available space — no card chrome — so it reads as part of the page.
struct ScanningLoaderView: View {
    let title: String
    let subtitle: String
    let progress: Double?
    let currentLocation: String?
    let scannedItemCount: Int
    let scanners: [ScannerLoaderItem]
    let cancelTitle: String
    let cancelAction: () -> Void
    let tint: Color

    @State private var appearProgress: CGFloat = 0

    init(
        title: String,
        subtitle: String,
        progress: Double? = nil,
        currentLocation: String? = nil,
        scannedItemCount: Int = 0,
        scanners: [ScannerLoaderItem] = [],
        cancelTitle: String = "Cancel Scan",
        tint: Color = AppTheme.accent,
        cancelAction: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.progress = progress
        self.currentLocation = currentLocation
        self.scannedItemCount = scannedItemCount
        self.scanners = scanners
        self.cancelTitle = cancelTitle
        self.tint = tint
        self.cancelAction = cancelAction
    }

    private var hasScanners: Bool { !scanners.isEmpty }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 28) {
                ScanningProgressRing(progress: progress, tint: tint)
                    .frame(width: 180, height: 180)

                header
                    .accessibilityElement(children: .combine)

                infoChips
            }
            .frame(maxWidth: 560)

            if hasScanners {
                scannerList
                    .frame(maxWidth: 900)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            cancelButton
        }
        .frame(maxWidth: .infinity)
        .opacity(appearProgress)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appearProgress = 1
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("scan-progress-title")

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.5)
                .frame(maxWidth: 440)
        }
    }

    /// Location pill + inspected count, shown inline when available.
    @ViewBuilder private var infoChips: some View {
        let hasLocation = currentLocation.map { !$0.isEmpty } ?? false
        if hasLocation || scannedItemCount > 0 {
            HStack(spacing: 10) {
                if hasLocation, let currentLocation {
                    locationChip(currentLocation)
                }
                if scannedItemCount > 0 {
                    inspectedBadge
                }
            }
        }
    }

    private func locationChip(_ path: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(AppTheme.hairline, lineWidth: 1)
        }
        .frame(maxWidth: 360)
    }

    private var inspectedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.caption2)
                .accessibilityHidden(true)
            Text("\(StorageFormatting.items(scannedItemCount)) inspected")
                .font(.caption.monospacedDigit())
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }

    /// A single scanner sits as one centred card so it doesn't look lonely
    /// stretched across a wide window. Two or more flow into a responsive,
    /// centred grid that wraps and centres every row — including a partial
    /// last row of 3 items on a 2-column layout.
    @ViewBuilder private var scannerList: some View {
        if scanners.count == 1 {
            ScannerLoaderRow(item: scanners[0])
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            CenteredFlowLayout(spacing: 12) {
                ForEach(scanners) { item in
                    ScannerLoaderRow(item: item)
                        .frame(minWidth: 220)
                }
            }
        }
    }

    private var cancelButton: some View {
        Button(cancelTitle, role: .cancel, action: cancelAction)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("cancel-scan-button")
    }
}

// MARK: - Scanner loader item model

/// One row in the `ScanningLoaderView`'s scanner list. Each `ScannerLoaderItem`
/// is the public input the view accepts; build them from
/// `ScannerProgress` (dashboard) or from per-view local state (self-loaders).
struct ScannerLoaderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let state: ScannerLoaderState
    let itemsScanned: Int
    let message: String
    let systemImage: String
    let tint: Color

    init(
        id: String,
        title: String,
        state: ScannerLoaderState,
        itemsScanned: Int = 0,
        message: String = "",
        systemImage: String? = nil,
        tint: Color? = nil
    ) {
        self.id = id
        self.title = title
        self.state = state
        self.itemsScanned = itemsScanned
        self.message = message
        self.systemImage = systemImage ?? Self.defaultSymbol(for: state)
        self.tint = tint ?? Self.defaultTint(for: state)
    }

    private static func defaultSymbol(for state: ScannerLoaderState) -> String {
        switch state {
        case .pending: "clock"
        case .scanning: "arrow.triangle.2.circlepath"
        case .completed: "checkmark"
        case .skipped: "minus"
        }
    }

    private static func defaultTint(for state: ScannerLoaderState) -> Color {
        switch state {
        case .pending, .skipped: .secondary
        case .scanning: AppTheme.accent
        case .completed: AppTheme.mint
        }
    }
}

enum ScannerLoaderState: Equatable, Sendable {
    case pending
    case scanning
    case completed
    case skipped
}

// MARK: - ScannerProgress adapter

extension ScannerLoaderItem {
    /// Adapter from the dashboard's `ScannerProgress` (which is owned by
    /// `Core/Models`) to the design-system `ScannerLoaderItem`. Keeps the
    /// two layers decoupled so a future redesign of either doesn't ripple.
    init(progress: ScannerProgress) {
        let state: ScannerLoaderState = switch progress.state {
        case .pending: .pending
        case .scanning: .scanning
        case .completed: .completed
        case .skipped: .skipped
        }
        self.init(
            id: progress.kind.rawValue,
            title: progress.title,
            state: state,
            itemsScanned: progress.inspectedItemCount,
            message: progress.message
        )
    }
}
