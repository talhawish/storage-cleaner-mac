import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection?
    let isScanning: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.symbolName)
                        .tag(section)
                }
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
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(AppTheme.mint)
                    .accessibilityHidden(true)
                Text("Nothing is deleted automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .navigationTitle("Storage Cleaner")
    }
}
