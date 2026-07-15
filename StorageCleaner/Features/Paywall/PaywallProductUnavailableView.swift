import SwiftUI

/// Actionable empty state shown when StoreKit returns no purchasable products.
struct PaywallProductUnavailableView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Plans temporarily unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection and try loading the App Store plans again.")
        } actions: {
            Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .accessibilityIdentifier("paywall-products-unavailable")
    }
}
