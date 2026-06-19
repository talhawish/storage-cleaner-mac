import SwiftData
import SwiftUI

struct CleanupHistoryView: View {
    @Query(
        sort: \StoredScan.date,
        order: .reverse
    )
    private var scans: [StoredScan]

    var body: some View {
        Group {
            if scans.isEmpty {
                AnimatedEmptyState(
                    title: "No History",
                    message: "Scan results and cleanup actions will appear here.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                historyList
            }
        }
        .navigationTitle("Cleanup History")
    }

    private var historyList: some View {
        List {
            Section("Recent Scans") {
                ForEach(scans) { scan in
                    HistoryRowView(scan: scan)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct HistoryRowView: View {
    let scan: StoredScan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass.circle.fill")
                    .foregroundStyle(AppTheme.accent)
                Text(scan.date, style: .date)
                    .font(.headline)
                + Text(" at ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                + Text(scan.date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                Label(StorageFormatting.bytes(scan.reclaimableBytes), systemImage: "externaldrive.badge.xmark")
                Label("\(scan.findings.count) categories", systemImage: "square.grid.2x2")
                Label(StorageFormatting.duration(.seconds(scan.durationSeconds)), systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !scan.cleanupActions.isEmpty {
                Divider()
                HStack {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(scan.cleanupActions.count) cleanup actions")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Text(StorageFormatting.bytes(totalReclaimed))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var totalReclaimed: Int64 {
        scan.cleanupActions.reduce(0) { $0 + $1.bytesReclaimed }
    }
}
