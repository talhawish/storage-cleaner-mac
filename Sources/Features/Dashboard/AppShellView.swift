import SwiftUI

struct AppShellView: View {
    @Bindable var viewModel: DashboardViewModel
    @State private var selection: AppSection? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, isScanning: viewModel.isScanning)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            Group {
                switch selection {
                case .overview, .none:
                    DashboardView(viewModel: viewModel)
                case let section?:
                    ComingSoonView(section: section)
                }
            }
            .background {
                LinearGradient(
                    colors: [
                        AppTheme.accent.opacity(0.055),
                        Color.clear,
                        AppTheme.violet.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(AppTheme.accent)
    }
}
