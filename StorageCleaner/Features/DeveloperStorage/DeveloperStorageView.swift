import SwiftUI

struct DeveloperStorageView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void
    @State private var selectedDomain: StorageDomain?

    private var allDeveloperFindings: [StorageFinding] {
        findings.filter { DeveloperDomains.kinds.contains($0.kind) }
    }

    private var detectedDomains: [StorageDomain] {
        DeveloperDomains.detected(in: findings)
    }

    private var developerFindings: [StorageFinding] {
        guard let selectedDomain else { return allDeveloperFindings }
        return allDeveloperFindings.filter { $0.domain == selectedDomain }
    }

    private var totalSize: Int64 {
        developerFindings.reduce(0) { $0 + $1.bytes }
    }

    private var title: String { selectedDomain?.title ?? "Developer Storage" }

    private var symbolName: String {
        selectedDomain?.symbolName ?? "chevron.left.forwardslash.chevron.right"
    }

    var body: some View {
        Group {
            if allDeveloperFindings.isEmpty {
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
        .onChange(of: detectedDomains) { _, domains in
            guard let selectedDomain, !domains.contains(selectedDomain) else { return }
            self.selectedDomain = nil
        }
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
            if !detectedDomains.isEmpty {
                Section {
                    DeveloperDomainSelector(
                        findings: allDeveloperFindings,
                        domains: detectedDomains,
                        selectedDomain: $selectedDomain
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 18, bottom: 14, trailing: 18))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    SectionHeader(
                        title: "Developer Domains",
                        subtitle: "Choose a domain to filter the artifacts below",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
            }

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
                    title: selectedDomain == nil ? "All developer artifacts" : title,
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

private struct DeveloperDomainSelector: View {
    let findings: [StorageFinding]
    let domains: [StorageDomain]
    @Binding var selectedDomain: StorageDomain?

    private var allBytes: Int64 {
        findings.reduce(0) { $0 + $1.bytes }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                DeveloperDomainTab(
                    title: "All",
                    count: findings.count,
                    bytes: allBytes,
                    systemImage: "square.grid.2x2.fill",
                    tint: AppTheme.accent,
                    isSelected: selectedDomain == nil
                ) {
                    selectedDomain = nil
                }

                ForEach(domains) { domain in
                    let domainFindings = findings.filter { $0.domain == domain }
                    DeveloperDomainTab(
                        title: domain.title,
                        count: domainFindings.count,
                        bytes: domainFindings.reduce(0) { $0 + $1.bytes },
                        systemImage: domain.symbolName,
                        tint: AppTheme.color(for: domain),
                        isSelected: selectedDomain == domain
                    ) {
                        selectedDomain = domain
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct DeveloperDomainTab: View {
    let title: String
    let count: Int
    let bytes: Int64
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityHidden(true)

                    Spacer(minLength: 6)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(StorageFormatting.bytes(bytes))
                        .font(.headline.monospacedDigit())

                    Text("\(count) categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: 178, height: 116, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? tint.opacity(0.16) : Color.secondary.opacity(0.08))
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isSelected ? tint : Color.clear)
                .frame(height: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.55) : Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityLabel("\(title), \(count) categories, \(StorageFormatting.bytes(bytes))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Filters developer artifacts")
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
