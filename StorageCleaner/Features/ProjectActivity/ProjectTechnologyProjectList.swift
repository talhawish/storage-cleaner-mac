import SwiftUI

struct ProjectTechnologyProjectList: View {
    let projects: [ProjectInfo]
    let permissionHandler: (any StoragePermissionHandling)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Projects")
                .font(.headline)

            LazyVStack(spacing: 0) {
                ForEach(projects) { project in
                    ProjectTechnologyProjectRow(
                        project: project,
                        permissionHandler: permissionHandler
                    )

                    if project.id != projects.last?.id {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.control)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
        }
    }
}
