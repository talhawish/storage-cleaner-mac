import AppKit
import SwiftData
import SwiftUI

@main
struct StorageCleanerApp: App {
    @State private var viewModel: DashboardViewModel
    @StateObject private var systemAppearance = SystemAppearanceObserver()
    @AppStorage("appearanceMode")
    private var appearanceMode: AppearanceMode = .system
    private let modelContainer: ModelContainer

    @MainActor
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
                .preferredColorScheme(appearanceMode.colorScheme ?? systemAppearance.colorScheme)
                .onAppear {
                    AppAppearance.apply(appearanceMode)
                }
                .onChange(of: appearanceMode) { _, newMode in
                    AppAppearance.apply(newMode)
                }
        }
        .defaultSize(width: 1_180, height: 760)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
private final class SystemAppearanceObserver: NSObject, ObservableObject {
    @Published var colorScheme: ColorScheme

    override init() {
        colorScheme = AppAppearance.currentSystemColorScheme
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc
    private func systemAppearanceDidChange() {
        DispatchQueue.main.async {
            self.colorScheme = AppAppearance.currentSystemColorScheme
        }
    }
}

@MainActor
private enum AppAppearance {
    static func apply(_ mode: AppearanceMode) {
        let appearance = mode.nsAppearanceName.flatMap(NSAppearance.init(named:))
        NSApp.appearance = appearance

        for window in NSApp.windows {
            window.appearance = appearance
        }
    }

    static var currentSystemColorScheme: ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
        return bestMatch == .darkAqua ? .dark : .light
    }
}
