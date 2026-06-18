import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 420), spacing: AppTheme.contentSpacing)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.contentSpacing) {
                header

                switch viewModel.phase {
                case .idle:
                    WelcomeHeroView(startScan: viewModel.startScan)
                    TrustStripView()
                case .scanning:
                    ScanProgressView(viewModel: viewModel)
                case .results:
                    results
                case .empty:
                    AnimatedEmptyState(
                        title: "Your developer storage is tidy",
                        message: "No re-creatable developer files were found in the selected locations.",
                        actionTitle: "Scan Again",
                        action: viewModel.startScan
                    )
                    .frame(minHeight: 430)
                case .permissionRequired:
                    PermissionRequiredView(
                        blockedPermissions: viewModel.blockedPermissions,
                        onOpenSettings: viewModel.openSystemSettings,
                        onRetry: viewModel.retryAfterPermission
                    )
                case let .failed(message):
                    ErrorStateView(message: message, retry: viewModel.startScan)
                }
            }
            .padding(28)
            .animation(reduceMotion ? nil : .snappy(duration: 0.42), value: viewModel.phase)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem {
                Button {
                    viewModel.startScan()
                } label: {
                    Label(viewModel.isScanning ? "Scanning…" : "Scan Now", systemImage: "sparkle.magnifyingglass")
                }
                .accessibilityIdentifier("toolbar-scan-button")
                .disabled(viewModel.isScanning)
                .keyboardShortcut("r", modifiers: [.command])
                .help("Start a new storage scan (⌘R)")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(greeting)
                .font(.largeTitle.bold())
            Text("Understand what is using space before deciding what to clean.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Label(viewModel.permissionSummary, systemImage: "lock.shield")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var results: some View {
        if let snapshot = viewModel.snapshot {
            ScanSummaryView(snapshot: snapshot, startScan: viewModel.startScan)

            HStack {
                Text("Detected storage candidates")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text("\(snapshot.findings.count) detection types")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: AppTheme.contentSpacing) {
                ForEach(snapshot.findings) { finding in
                    StorageCategoryCard(finding: finding)
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }
}
