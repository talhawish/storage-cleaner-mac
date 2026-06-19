import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    let isScanning: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Navigate") {
                SidebarRow(section: .overview)
                SidebarRow(section: .projectActivity)
                SidebarRow(section: .apps)
            }

            Section("Developer") {
                SidebarRow(section: .developerStorage)
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
                SidebarRow(section: .settings)
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
            .accessibilityIdentifier("sidebar-\(section.rawValue)")
    }
}
