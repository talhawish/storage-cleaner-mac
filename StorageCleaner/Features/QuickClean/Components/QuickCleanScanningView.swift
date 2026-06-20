import SwiftUI

/// The "scanning in progress" state. Shows a progress ring and a "category N
/// of M" counter so the user can see that the scan is making forward
/// progress, not stuck.
struct QuickCleanScanningView: View {
    let progress: QuickCleanViewModel.Progress

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            QuickCleanProgressRing(
                fraction: progress.fraction,
                isIndeterminate: progress.isIndeterminate
            )
            VStack(spacing: 6) {
                Text(headline)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(28)
    }

    private var headline: String {
        if progress.totalCategories == 0 {
            return "Preparing scan…"
        }
        return "Scanning safe-to-delete items…"
    }

    private var detail: String {
        if progress.totalCategories == 0 {
            return "Resolving categories"
        }
        return "Category \(progress.completedCategories) of \(progress.totalCategories)"
    }
}
