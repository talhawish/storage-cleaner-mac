import SwiftData
import SwiftUI

@main
struct StorageCleanerApp: App {
    @State private var viewModel: DashboardViewModel
    @AppStorage("appearanceMode")
    private var appearanceMode: AppearanceMode = .system
    private let modelContainer: ModelContainer

    init() {
        let arguments = CommandLine.arguments
        let container = AppContainer.current(arguments: arguments)

        // Demo/UI-test runs use an ephemeral store so they never write to the user's history.
        let usesEphemeralStore = arguments.contains("--use-demo-scanner")
        let modelContainer = usesEphemeralStore
            ? PersistenceController.makeInMemory()
            : PersistenceController.shared
        let historyStore = SwiftDataScanHistoryStore(context: modelContainer.mainContext)

        self.modelContainer = modelContainer
        _viewModel = State(
            initialValue: DashboardViewModel(
                scanner: container.storageScanner,
                permissionHandler: container.permissionHandler,
                cleanupService: container.cleanupService,
                historyStore: historyStore
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppShellView(viewModel: viewModel)
                .frame(minWidth: 920, minHeight: 640)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
    }
}
