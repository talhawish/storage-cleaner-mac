import SwiftUI

struct MediaPaginationFooter: View {
    let visibleCount: Int
    let totalCount: Int
    let onLoadMore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(visibleCount) of \(totalCount) shown")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onLoadMore) {
                Label("Load More", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .onAppear(perform: onLoadMore)
    }
}
