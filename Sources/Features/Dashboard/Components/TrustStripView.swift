import SwiftUI

struct TrustStripView: View {
    private let items = [
        ("lock.shield.fill", "Read-only scan"),
        ("bolt.fill", "Runs off the main thread"),
        ("hand.raised.fill", "You approve every cleanup")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(items, id: \.1) { symbol, title in
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
