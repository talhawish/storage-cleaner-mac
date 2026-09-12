import SwiftUI

struct ProjectFrameworkBreakdownView: View {
    let entries: [ProjectFrameworkCount]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Frameworks")
                .font(.headline)
            Text("Counts include nested workspace projects. Storage totals count each root once.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: AppTheme.Spacing.medium)],
                alignment: .leading,
                spacing: AppTheme.Spacing.medium
            ) {
                ForEach(entries) { entry in
                    ProjectFrameworkTile(entry: entry)
                }
            }
        }
    }
}
