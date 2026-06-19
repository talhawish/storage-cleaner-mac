import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Binding var showSettings: Bool
    let isScanning: Bool
    /// Developer domains detected by the latest scan; rendered as dynamic rows under Developer.
    let developerDomains: [StorageDomain]

    var body: some View {
        List(selection: $selection) {
            Section("Navigate") {
                SidebarRow(section: .overview)
                SidebarRow(section: .projectActivity)
                SidebarRow(section: .apps)
            }

            Section("Developer") {
                SidebarRow(section: .developerStorage)
                ForEach(developerDomains) { domain in
                    SidebarDomainRow(domain: domain)
                }
                SidebarRow(section: .runtimeVersions)
                SidebarRow(section: .simulatorsEmulators)
                SidebarRow(section: .cliPrograms)
            }

            Section("Media") {
                SidebarRow(section: .largeFiles)
                SidebarRow(section: .leftovers)
                SidebarRow(section: .screenshotsAndRecordings)
                SidebarRow(section: .duplicates)
            }

            Section("Manage") {
                SidebarRow(section: .cleanupHistory)
            }

            Section("Status") {
                HStack(spacing: 10) {
                    Circle()
                        .fill(isScanning ? AppTheme.orange : AppTheme.mint)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text(isScanning ? "Scan in progress" : "Ready to scan")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text("Settings")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(AppTheme.mint)
                        .font(.system(size: 11))
                        .accessibilityHidden(true)
                    Text("Nothing is deleted automatically")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Storage Cleaner")
    }
}

private struct SidebarRow: View {
    let section: AppSection

    var body: some View {
        Label(section.title, systemImage: section.symbolName)
            .tag(SidebarItem.section(section))
    }
}

/// A dynamic developer-domain row, indented to read as a child of "Developer Storage".
private struct SidebarDomainRow: View {
    let domain: StorageDomain

    var body: some View {
        Label {
            Text(domain.title)
        } icon: {
            Image(systemName: domain.symbolName)
                .foregroundStyle(AppTheme.color(for: domain))
                .accessibilityHidden(true)
        }
        .padding(.leading, 14)
        .tag(SidebarItem.developerDomain(domain))
    }
}
