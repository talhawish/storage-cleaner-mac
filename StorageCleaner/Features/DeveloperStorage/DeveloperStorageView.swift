import SwiftUI

struct DeveloperStorageView: View {
    let findings: [StorageFinding]
    let onScan: () -> Void
    let onDelete: ([URL]) -> Void
    let onOpenFinding: (StorageFinding) -> Void
    let onRemoveRuntimeVersions: ([URL]) async -> Void
    @State private var selectedDomain: StorageDomain?

    private var detectedDomains: [StorageDomain] {
        DeveloperDomains.detected(in: findings)
    }

    /// Findings to render as rows. Excludes the `.runtimeVersions` finding because it
    /// is presented by the embedded ``RuntimeVersionsSection`` below, which does its
    /// own live discovery and sizing — surfacing the finding both ways would duplicate
    /// the same data and the section's per-version selection.
    private var developerFindings: [StorageFinding] {
        let base = findings.filter { $0.kind != .runtimeVersions }
        guard let selectedDomain else { return base }
        return base.filter { $0.domain == selectedDomain }
    }

    private var totalSize: Int64 {
        developerFindings.reduce(0) { $0 + $1.bytes }
    }

    private var title: String { selectedDomain?.title ?? "Developer Storage" }

    private var symbolName: String {
        selectedDomain?.symbolName ?? "chevron.left.forwardslash.chevron.right"
    }

    /// Whether the embedded Runtime Versions section should appear. The section is
    /// always relevant for the "All" view and for the `otherCaches` filter (which is
    /// where `.runtimeVersions` is bucketed) but is hidden when the user is focused
    /// on a single non-runtime domain.
    private var shouldShowRuntimeVersionsSection: Bool {
        guard let selectedDomain else { return true }
        return selectedDomain == .otherCaches
    }

    var body: some View {
        Group {
            // The Runtime Versions section does its own live discovery, so it can
            // surface useful work even when the scan-based findings are empty.
            // Show the calm empty state only when there are no findings *and* the
            // runtime section is hidden (e.g. the user is filtered to a non-runtime
            // domain).
            if findings.isEmpty, !shouldShowRuntimeVersionsSection {
                EmptyStateView(
                    title: "Nothing to clean here",
                    message: "No re-creatable developer files were found in the selected locations. "
                        + "Run another scan if you've built new projects since the last one.",
                    systemImage: symbolName,
                    tint: AppTheme.color(for: selectedDomain ?? .appleDevelopment),
                    actionTitle: "Scan Again",
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
                    Label("Scan Now", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("developer-storage-scan-button")
                .keyboardShortcut("r", modifiers: [.command])
                .help("Scan developer storage locations again")
            }
        }
        .accessibilityIdentifier("developer-storage-root")
    }

    private var developerList: some View {
        List {
            if !detectedDomains.isEmpty {
                Section {
                    DeveloperDomainSelector(
                        findings: findings,
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
                    Button {
                        onOpenFinding(finding)
                    } label: {
                        DeveloperStorageRow(finding: finding)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rowAccessibilityLabel(for: finding))
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

            if shouldShowRuntimeVersionsSection {
                Section {
                    RuntimeVersionsSection(onRemove: onRemoveRuntimeVersions)
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    SectionHeader(
                        title: "Runtime Versions",
                        subtitle: "Multiple versions of the same runtime kept by your version managers",
                        systemImage: "square.stack.3d.up.fill"
                    )
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func rowAccessibilityLabel(for finding: StorageFinding) -> String {
        "\(finding.kind.title), \(StorageFormatting.bytes(finding.bytes)), "
            + "\(StorageFormatting.items(finding.itemCount))"
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
                StatCardTab(
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
                    StatCardTab(
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
        .contentShape(Rectangle())
    }
}
