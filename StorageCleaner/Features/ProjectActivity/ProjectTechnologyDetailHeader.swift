import SwiftUI

struct ProjectTechnologyDetailHeader: View {
    let detail: ProjectTechnologyDetail

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: detail.technology.symbolName)
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: detail.technology.color))
                .frame(width: 56, height: 56)
                .background(
                    Color(hex: detail.technology.color).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.technology.rawValue)
                    .font(.title.bold())
                Text(detail.activitySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
