import SwiftUI

struct ProjectTechnologyDetailView: View {
    let detail: ProjectTechnologyDetail
    let threshold: InactivityThreshold
    let permissionHandler: (any StoragePermissionHandling)?

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProjectTechnologyDetailHeader(detail: detail)
                    ProjectTechnologyMetricsView(detail: detail, threshold: threshold)

                    if !detail.frameworkBreakdown.isEmpty {
                        ProjectFrameworkBreakdownView(entries: detail.frameworkBreakdown)
                    }

                    ProjectTechnologyProjectList(
                        projects: detail.projects,
                        permissionHandler: permissionHandler
                    )
                }
                .padding(24)
            }
            .navigationTitle("\(detail.technology.rawValue) Projects")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 560)
    }
}
