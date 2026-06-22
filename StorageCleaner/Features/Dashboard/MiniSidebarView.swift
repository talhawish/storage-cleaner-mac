import SwiftUI

/// A collapsed, icon-only variant of the sidebar.
///
/// Toggling the sidebar toolbar button collapses the full `SidebarView` into
/// this narrow column so the active section remains visible and one-click
/// accessible without losing the navigational context entirely.
struct MiniSidebarView: View {
    @Binding var selection: SidebarItem?
    let isScanning: Bool
    @State private var isDockerInstalled = DockerService.live.isInstalled

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppTheme.MiniSidebar.groupSpacing) {
                    MiniSidebarGroup {
                        MiniSidebarButton(section: .overview, selection: $selection)
                        MiniSidebarButton(section: .projectActivity, selection: $selection)
                        MiniSidebarButton(section: .apps, selection: $selection)
                    }

                    MiniSidebarGroup {
                        MiniSidebarButton(section: .developerStorage, selection: $selection)
                        if isDockerInstalled {
                            MiniSidebarButton(section: .docker, selection: $selection)
                        }
                        MiniSidebarButton(section: .simulatorsEmulators, selection: $selection)
                        MiniSidebarButton(section: .cliPrograms, selection: $selection)
                    }

                    MiniSidebarGroup {
                        MiniSidebarButton(section: .largeFiles, selection: $selection)
                        MiniSidebarButton(section: .leftovers, selection: $selection)
                        MiniSidebarButton(section: .screenshotsAndRecordings, selection: $selection)
                        MiniSidebarButton(section: .duplicates, selection: $selection)
                    }

                    MiniSidebarGroup {
                        MiniSidebarButton(section: .systemJunk, selection: $selection)
                    }

                    MiniSidebarGroup {
                        MiniSidebarButton(section: .cleanupHistory, selection: $selection)
                        MiniSidebarButton(section: .settings, selection: $selection)
                    }
                }
                .padding(.vertical, AppTheme.MiniSidebar.verticalPadding)
            }

            Spacer()

            VStack(spacing: 0) {
                Divider()

                ZStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(AppTheme.mint)
                        .font(.system(size: AppTheme.MiniSidebar.iconSize))
                }
                .frame(height: AppTheme.MiniSidebar.footerHeight)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .tooltip("Nothing is deleted automatically")
                .accessibilityLabel("Nothing is deleted automatically")

                Divider()

                ZStack {
                    Circle()
                        .fill(isScanning ? AppTheme.orange : AppTheme.mint)
                        .frame(
                            width: AppTheme.MiniSidebar.statusIndicatorSize,
                            height: AppTheme.MiniSidebar.statusIndicatorSize
                        )
                }
                .frame(width: AppTheme.MiniSidebar.buttonSize, height: AppTheme.MiniSidebar.buttonSize)
                .contentShape(Rectangle())
                .tooltip(isScanning ? "Scan in progress" : "Ready to scan")
                .accessibilityLabel(isScanning ? "Scan in progress" : "Ready to scan")
            }
        }
        .frame(width: AppTheme.MiniSidebar.width)
        .task {
            isDockerInstalled = DockerService.live.isInstalled
        }
    }
}

// MARK: - Components

private struct MiniSidebarGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: AppTheme.MiniSidebar.itemSpacing) {
            content
        }
    }
}

private struct MiniSidebarButton: View {
    let section: AppSection
    @Binding var selection: SidebarItem?

    private var isSelected: Bool { selection?.section == section }

    var body: some View {
        Button {
            selection = .section(section)
        } label: {
            ZStack {
                Image(systemName: section.symbolName)
                    .font(.system(size: AppTheme.MiniSidebar.iconSize, weight: .medium))
            }
            .frame(width: AppTheme.MiniSidebar.buttonSize, height: AppTheme.MiniSidebar.buttonSize)
            .contentShape(Rectangle())
            .tooltip(section.title)
        }
        .buttonStyle(MiniSidebarButtonStyle(isSelected: isSelected))
        .accessibilityLabel(section.title)
        .accessibilityIdentifier("sidebar-\(section.rawValue)")
    }
}

private struct MiniSidebarButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.MiniSidebar.cornerRadius, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.15) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
