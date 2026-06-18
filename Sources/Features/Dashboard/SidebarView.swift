import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection?
    @Binding var showSettings: Bool
    let isScanning: Bool

    var body: some View {
        List(selection: $selection) {
            Section("Navigate") {
                SidebarRow(section: .overview)
                SidebarRow(section: .projectActivity)
                SidebarRow(section: .apps)
                SidebarRow(section: .developerStorage)
                SidebarRow(section: .cliPrograms)
            }

            Section("Media") {
                SidebarRow(section: .largeFiles)
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
            .tag(section)
    }
}
