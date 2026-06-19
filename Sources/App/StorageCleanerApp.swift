import SwiftData
import SwiftUI

@main
struct StorageCleanerApp: App {
    @State private var viewModel: DashboardViewModel

    init() {
        let container = AppContainer.current()
        _viewModel = State(
            initialValue: DashboardViewModel(
                scanner: container.storageScanner,
                permissionHandler: container.permissionHandler,
                cleanupService: container.cleanupService
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
        .modelContainer(PersistenceController.shared)

        Settings {
            SettingsView()
        }
    }
}
