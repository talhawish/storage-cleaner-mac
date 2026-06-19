import SwiftUI

struct DeveloperStorageView: View {
    let findings: [StorageFinding]
    /// When set, only findings in this domain are shown (used by the dynamic per-domain sidebar
    /// rows). `nil` shows the full developer overview.
    var domainFilter: StorageDomain?
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void

    private var developerFindings: [StorageFinding] {
        findings.filter { finding in
            DeveloperDomains.kinds.contains(finding.kind)
                && (domainFilter == nil || finding.domain == domainFilter)
        }
    }

    private var totalSize: Int64 {
        developerFindings.reduce(0) { $0 + $1.bytes }
    }

    private var title: String { domainFilter?.title ?? "Developer Storage" }

    private var symbolName: String {
        domainFilter?.symbolName ?? "chevron.left.forwardslash.chevron.right"
    }

    var body: some View {
        Group {
            if developerFindings.isEmpty {
                AnimatedEmptyState(
                    title: title,
                    message: "Run a scan to discover developer storage artifacts.",
                    actionTitle: "Scan Now",
                    systemImage: symbolName,
                    action: onScan
                )
            } else {
                developerList
            }
        }
        .navigationTitle(title)
        .navigationSubtitle("\(developerFindings.count) categories, \(StorageFormatting.bytes(totalSize))")
        .toolbar {
            ToolbarItem {
                Button(action: onScan) {
                    Label("Scan Now", systemImage: "sparkle.magnifyingglass")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan developer storage locations again")
            }
        }
    }

    private var developerList: some View {
        List {
            Section {
                ForEach(developerFindings) { finding in
                    NavigationLink {
                        CategoryDetailView(finding: finding, onDelete: onDelete)
                    } label: {
                        DeveloperStorageRow(finding: finding)
                    }
                }
            } header: {
                SectionHeader(
                    title: domainFilter == nil ? "All developer artifacts" : title,
                    systemImage: symbolName
                ) {
                    Text(StorageFormatting.bytes(totalSize))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct DeveloperStorageRow: View {
    let finding: StorageFinding

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.color(for: finding.domain).opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: finding.domain.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.color(for: finding.domain))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(finding.kind.title)
                    .font(.headline)
                Text(finding.kind.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(StorageFormatting.bytes(finding.bytes))
                    .font(.callout.monospacedDigit().weight(.medium))
                Text("\(finding.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
