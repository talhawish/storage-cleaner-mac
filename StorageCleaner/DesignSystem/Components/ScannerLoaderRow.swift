import SwiftUI

/// One row in the `ScanningLoaderView`'s scanner list. Displays a named
/// scanner with its icon, current state, and item count. State transitions
/// (pending → scanning → completed) animate smoothly: the active scanner's
/// icon spins, its card gets a subtle tinted border-glow, and a shimmering
/// progress bar slides along the bottom edge.
struct ScannerLoaderRow: View {
    let item: ScannerLoaderItem

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @State private var iconRotation: Double = 0
    @State private var spinning = false
    @State private var shimmerOffset: CGFloat = -1

    private let cornerRadius: CGFloat = 14

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                iconView
                labelView
                Spacer(minLength: 4)
                stateIndicator
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if item.state == .scanning {
                shimmerBar
                    .transition(.opacity)
            }
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(statusText)")
        .onChange(of: item.state) { _, newState in
            handleStateChange(newState)
        }
        .onAppear { handleAppear() }
    }

    // MARK: - Subviews

    private var iconView: some View {
        Image(systemName: item.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(item.tint)
            .frame(width: 30, height: 30)
            .background(item.tint.opacity(0.12), in: Circle())
            .rotationEffect(.degrees(iconRotation))
            .accessibilityHidden(true)
    }

    private var labelView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder private var stateIndicator: some View {
        switch item.state {
        case .scanning:
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(item.tint)
                .accessibilityHidden(true)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.mint)
                .accessibilityHidden(true)
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .skipped:
            Image(systemName: "minus.circle")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    /// A thin shimmering bar along the bottom edge that communicates "work is
    /// happening" without needing per-scanner progress data.
    private var shimmerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(item.tint.opacity(0.07))
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                item.tint.opacity(0),
                                item.tint.opacity(0.7),
                                item.tint.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: geo.size.width * shimmerOffset)
            }
        }
        .frame(height: 2)
        .clipShape(RoundedRectangle(cornerRadius: 1, style: .continuous))
    }

    // MARK: - Derived

    private var borderColor: Color {
        switch item.state {
        case .scanning: item.tint.opacity(0.18)
        case .completed: AppTheme.mint.opacity(0.12)
        default: AppTheme.hairline
        }
    }

    private var statusText: String {
        if item.itemsScanned > 0 {
            return "\(StorageFormatting.items(item.itemsScanned)) items · \(item.message)"
        }
        return item.message
    }

    // MARK: - Animation

    private func handleAppear() {
        guard !reduceMotion, item.state == .scanning else { return }
        startSpin()
        startShimmer()
    }

    private func handleStateChange(_ newState: ScannerLoaderState) {
        guard !reduceMotion else { return }
        if newState == .scanning {
            startSpin()
            startShimmer()
        } else {
            stopSpin()
        }
    }

    private func startSpin() {
        guard !spinning else { return }
        spinning = true
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            iconRotation = 360
        }
    }

    private func stopSpin() {
        guard spinning else { return }
        spinning = false
        withAnimation(.linear(duration: 0.3)) {
            iconRotation = 0
        }
    }

    private func startShimmer() {
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            shimmerOffset = 1.35
        }
    }
}
