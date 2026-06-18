import SwiftUI

@main
struct StorageCleanerApp: App {
    @State private var viewModel: DashboardViewModel

    init() {
        let container = AppContainer.current
        _viewModel = State(
            initialValue: DashboardViewModel(
                scanner: container.storageScanner,
                permissionHandler: container.permissionHandler
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: viewModel)
                .frame(minWidth: 920, minHeight: 640)
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

private extension AppContainer {
    static var current: AppContainer {
        ProcessInfo.processInfo.arguments.contains("--use-demo-scanner") ? .uiTesting : .live
    }
}
